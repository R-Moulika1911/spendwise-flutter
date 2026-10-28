import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/category_repository.dart';
import '../models/category.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider({CategoryRepository? repository})
      : _repo = repository ?? CategoryRepository();

  final CategoryRepository _repo;
  final _uuid = const Uuid();

  List<ExpenseCategory> _categories = [];
  bool _loading = false;
  String? _error;

  List<ExpenseCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _loading;
  String? get error => _error;

  ExpenseCategory? byId(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _categories = await _repo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> add({
    required String name,
    required String iconKey,
    required int colorValue,
  }) async {
    final existing = _categories.map((c) => c.name).toList();
    final trimmed = name.trim();
    if (existing.any((n) => n.toLowerCase() == trimmed.toLowerCase())) {
      return 'Category name already exists';
    }
    final category = ExpenseCategory(
      id: _uuid.v4(),
      name: trimmed,
      iconKey: iconKey,
      colorValue: colorValue,
    );
    await _repo.insert(category);
    await load();
    return null;
  }

  Future<String?> updateCategory(ExpenseCategory category) async {
    final existing = _categories
        .where((c) => c.id != category.id)
        .map((c) => c.name)
        .toList();
    if (existing.any(
      (n) => n.toLowerCase() == category.name.trim().toLowerCase(),
    )) {
      return 'Category name already exists';
    }
    await _repo.update(category.copyWith(name: category.name.trim()));
    await load();
    return null;
  }

  Future<DeleteCategoryResult> delete(String id) async {
    final result = await _repo.delete(id);
    if (result == DeleteCategoryResult.deleted ||
        result == DeleteCategoryResult.movedToOther) {
      await load();
    }
    return result;
  }
}
