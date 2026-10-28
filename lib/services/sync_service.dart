import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/category_repository.dart';
import '../data/expense_repository.dart';
import '../data/recurring_repository.dart';
import '../data/settings_repository.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/recurring_expense.dart';
import 'firebase_service.dart';

class SyncResult {
  final int expensesUploaded;
  final int expensesDownloaded;
  final int categoriesSynced;
  final int recurringSynced;
  final bool remoteSetupComplete;
  final String? message;

  const SyncResult({
    this.expensesUploaded = 0,
    this.expensesDownloaded = 0,
    this.categoriesSynced = 0,
    this.recurringSynced = 0,
    this.remoteSetupComplete = false,
    this.message,
  });
}

class SyncService {
  SyncService({
    ExpenseRepository? expenseRepository,
    CategoryRepository? categoryRepository,
    RecurringRepository? recurringRepository,
    SettingsRepository? settingsRepository,
  })  : _expenses = expenseRepository ?? ExpenseRepository(),
        _categories = categoryRepository ?? CategoryRepository(),
        _recurring = recurringRepository ?? RecurringRepository(),
        _settings = settingsRepository ?? SettingsRepository();

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final RecurringRepository _recurring;
  final SettingsRepository _settings;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<SyncResult> syncAll() async {
    if (!FirebaseService.isReady) {
      return SyncResult(message: FirebaseService.initError ?? 'Firebase unavailable');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SyncResult(message: 'Sign in to sync');
    }

    final uid = user.uid;
    final userRef = _userDoc(uid);

    // Categories: push then pull (replace by id)
    final localCats = await _categories.getAll();
    final catCol = userRef.collection('categories');
    final catBatch = FirebaseFirestore.instance.batch();
    for (final cat in localCats) {
      catBatch.set(catCol.doc(cat.id), cat.toMap()..['isDefault'] = cat.isDefault);
    }
    await catBatch.commit();

    final remoteCats = await catCol.get();
    for (final doc in remoteCats.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      data['isDefault'] = data['isDefault'] == true || data['isDefault'] == 1;
      final category = ExpenseCategory(
        id: data['id'] as String,
        name: data['name'] as String,
        iconKey: data['iconKey'] as String,
        colorValue: (data['colorValue'] as num).toInt(),
        isDefault: data['isDefault'] as bool,
      );
      final existing = await _categories.getById(category.id);
      if (existing == null) {
        try {
          await _categories.insert(category);
        } catch (_) {
          // name unique conflict — skip
        }
      } else {
        await _categories.update(category);
      }
    }

    // Expenses: merge by updatedAt
    final localExpenses = await _expenses.getAll();
    final expCol = userRef.collection('expenses');
    var uploaded = 0;
    var downloaded = 0;

    final remoteSnap = await expCol.get();
    final remoteById = {
      for (final d in remoteSnap.docs) d.id: d.data(),
    };

    for (final expense in localExpenses) {
      final remote = remoteById[expense.id];
      final shouldUpload = remote == null ||
          DateTime.parse(expense.updatedAt.toIso8601String()).isAfter(
            DateTime.parse(
              (remote['updatedAt'] as String?) ?? '1970-01-01',
            ),
          );
      if (shouldUpload) {
        await expCol.doc(expense.id).set(expense.toMap());
        uploaded++;
      }
    }

    for (final entry in remoteById.entries) {
      final data = Map<String, dynamic>.from(entry.value);
      data['id'] = entry.key;
      final remoteExpense = Expense.fromMap(data);
      final local = await _expenses.getById(remoteExpense.id);
      if (local == null) {
        await _expenses.insert(remoteExpense);
        downloaded++;
      } else if (remoteExpense.updatedAt.isAfter(local.updatedAt)) {
        await _expenses.update(remoteExpense);
        downloaded++;
      }
    }

    // Recurring
    final localRecurring = await _recurring.getAll();
    final recCol = userRef.collection('recurring');
    final recBatch = FirebaseFirestore.instance.batch();
    for (final item in localRecurring) {
      recBatch.set(recCol.doc(item.id), item.toFirestore());
    }
    await recBatch.commit();

    final remoteRec = await recCol.get();
    final mergedRecurring = <RecurringExpense>[];
    for (final doc in remoteRec.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      mergedRecurring.add(RecurringExpense.fromMap(data));
    }
    if (mergedRecurring.isNotEmpty) {
      await _recurring.upsertAll(mergedRecurring);
    }

    // Settings: pull remote first so returning users keep their currency/budget
    final localSettings = await _settings.load();
    final userSnap = await userRef.get();
    final remoteMap =
        userSnap.data()?['settings'] as Map<String, dynamic>?;
    final remoteSetupComplete = remoteMap?['setupComplete'] == true;

    // Returning accounts that finished setup (or already have a cloud budget)
    final remoteLooksConfigured = remoteMap != null &&
        (remoteSetupComplete || remoteMap['monthlyBudget'] != null);

    final AppSettings mergedSettings;
    if (remoteMap != null && remoteLooksConfigured) {
      // Existing account — prefer cloud values, skip local setup screen
      mergedSettings = AppSettings.fromFirestore(
        remoteMap,
        fallback: localSettings,
      ).copyWith(setupComplete: true);
    } else if (localSettings.setupComplete) {
      mergedSettings = localSettings;
    } else if (remoteMap != null) {
      mergedSettings = AppSettings.fromFirestore(
        remoteMap,
        fallback: localSettings,
      );
    } else {
      mergedSettings = localSettings;
    }

    await _settings.save(mergedSettings);
    await userRef.set({
      'settings': mergedSettings.toFirestore(),
      'email': user.email,
      'syncedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    return SyncResult(
      expensesUploaded: uploaded,
      expensesDownloaded: downloaded,
      categoriesSynced: localCats.length,
      recurringSynced: localRecurring.length,
      remoteSetupComplete: mergedSettings.setupComplete,
      message: 'Synced successfully',
    );
  }
}
