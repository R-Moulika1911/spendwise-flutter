// Generated from android/app/google-services.json
// For iOS, add an iOS app in Firebase and update the ios block (or run flutterfire configure).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isConfigured {
    const dummy = 'YOUR_';
    return !android.apiKey.startsWith(dummy) &&
        !android.appId.contains('000000000000');
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is out of scope for SpendWise v1.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCWQFWF8WXaYnG-EdnNX4HEhXRvcdsMEqg',
    appId: '1:144590340164:android:c29429510194da6aa83c11',
    messagingSenderId: '144590340164',
    projectId: 'spendwise-cfb28',
    storageBucket: 'spendwise-cfb28.firebasestorage.app',
  );

  // Placeholder until you add an iOS app in Firebase Console
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCWQFWF8WXaYnG-EdnNX4HEhXRvcdsMEqg',
    appId: '1:144590340164:ios:0000000000000000000000',
    messagingSenderId: '144590340164',
    projectId: 'spendwise-cfb28',
    storageBucket: 'spendwise-cfb28.firebasestorage.app',
    iosBundleId: 'com.spendwise.spendwise',
  );
}
