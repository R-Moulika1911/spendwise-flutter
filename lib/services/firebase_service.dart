import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseService {
  FirebaseService._();

  static bool _ready = false;
  static String? _initError;

  static bool get isReady => _ready;
  static String? get initError => _initError;

  static Future<void> initialize() async {
    if (_ready) return;
    if (!DefaultFirebaseOptions.isConfigured) {
      _initError =
          'Firebase is not configured yet. Run flutterfire configure after creating your Firebase project.';
      debugPrint(_initError);
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
      _initError = null;
    } catch (e) {
      _ready = false;
      _initError = e.toString();
      debugPrint('Firebase init failed: $e');
    }
  }
}
