# Firebase setup (you create the project)

The app works **fully offline** until Firebase is configured. Auth, Firestore sync, and the Node backend need your Firebase project.

## 1. Create the Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a project (e.g. `spendwise`)
3. Add an **Android** app with package name: `com.spendwise.spendwise`
4. Download `google-services.json` → place in `android/app/`
5. (Optional) Add an **iOS** app and put `GoogleService-Info.plist` in `ios/Runner/`

## 2. Enable products

- **Authentication** → Sign-in method → enable **Email/Password**
- **Firestore Database** → Create database (start in test mode for development, then tighten rules)

Suggested rules for personal sync (tighten later):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 3. Generate Flutter options

```bash
dart pub global activate flutterfire_cli
cd spendwise-flutter
flutterfire configure
```

This replaces `lib/firebase_options.dart` with real keys.

## 4. Backend service account

For `spendwise-backend`:

1. Project settings → Service accounts → Generate new private key
2. Save as `spendwise-backend/serviceAccountKey.json`
3. See that folder’s README

## 5. Notifications (FCM)

Cloud Messaging is enabled in the app for:

- **Local system notifications** when monthly budget is exceeded
- **FCM token** saved on the user doc (`fcmTokens`) after sign-in
- Receiving remote pushes if you send them from Firebase Console → Messaging

Allow notifications when Android asks (Android 13+).

Test: Settings → **Test budget notification**

## 6. Verify in the app

1. `flutter run`
2. Settings → Account → create account / sign in
3. Settings → Sync now
4. Settings → Test budget notification (optional)
