import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/firebase_service.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({SyncService? syncService})
      : _syncService = syncService ?? SyncService();

  final SyncService _syncService;
  bool _busy = false;
  String? _error;
  SyncResult? _lastSync;

  bool get isFirebaseReady => FirebaseService.isReady;
  String? get firebaseError => FirebaseService.initError;
  bool get isBusy => _busy;
  String? get error => _error;
  SyncResult? get lastSync => _lastSync;
  User? get user =>
      FirebaseService.isReady ? FirebaseAuth.instance.currentUser : null;
  bool get isSignedIn => user != null;
  String? get email => user?.email;

  Stream<User?>? get authStateChanges =>
      FirebaseService.isReady ? FirebaseAuth.instance.authStateChanges() : null;

  Future<bool> signIn(String email, String password) async {
    return _runAuth(() async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  Future<bool> register(String email, String password) async {
    return _runAuth(() async {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  Future<void> signOut() async {
    if (!FirebaseService.isReady) return;
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  Future<SyncResult> syncNow() async {
    if (!FirebaseService.isReady) {
      _lastSync = SyncResult(message: FirebaseService.initError);
      notifyListeners();
      return _lastSync!;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _lastSync = await _syncService.syncAll();
      return _lastSync!;
    } catch (e) {
      _error = e.toString();
      _lastSync = SyncResult(message: e.toString());
      return _lastSync!;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _runAuth(Future<void> Function() action) async {
    if (!FirebaseService.isReady) {
      _error = FirebaseService.initError ?? 'Firebase is not configured';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? e.code;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
