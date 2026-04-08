# PetaFinds — Setup Guide

## Prerequisites

- Flutter SDK 3.38+ installed and on PATH
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)
- A Firebase project created at https://console.firebase.google.com
- Android Studio / Xcode for emulators (optional)

## Step-by-Step Setup

### 1. Clone and Install Dependencies

```bash
cd PetaFinds
flutter pub get
```

### 2. Firebase Configuration

```bash
# Login to Firebase
firebase login

# Configure Firebase for this Flutter project
flutterfire configure
```

This generates `lib/firebase_options.dart`. Then update `lib/main.dart`:

1. Uncomment the import: `import 'firebase_options.dart';`
2. Uncomment the options parameter:
   ```dart
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

### 3. Enable Firebase Services

In the Firebase Console:

1. **Authentication** → Enable Email/Password sign-in
2. **Cloud Firestore** → Create database (start in test mode, then deploy rules)
3. **Firebase Storage** → Enable storage
4. **Cloud Messaging** → Enabled by default

### 4. Deploy Security Rules

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

Rules are in `firebase/firestore.rules` and `firebase/storage.rules`.

### 5. Seed Initial Data

Create the `categories` collection in Firestore with documents like:

| name | iconName | isActive |
|------|----------|----------|
| Restaurant | restaurant | true |
| Retail | shopping | true |
| Health | medical | true |
| Education | education | true |
| Electronics | electronics | true |
| Beauty | beauty | true |
| Automotive | automotive | true |
| Services | services | true |

### 6. Create Admin User

1. Sign up with a normal account
2. In Firestore Console, navigate to `users/{uid}` and change `role` to `"admin"`

### 7. App Check (Recommended for Production)

1. Firebase Console → App Check → Register your app
2. Add `firebase_app_check` to pubspec.yaml
3. Initialize in main.dart:
   ```dart
   await FirebaseAppCheck.instance.activate(
     androidProvider: AndroidProvider.playIntegrity,
     appleProvider: AppleProvider.appAttest,
   );
   ```

### 8. Run

```bash
# Android
flutter run

# iOS (macOS only)
flutter run -d ios

# Web
flutter run -d chrome
```

## Environment Variables

No .env file is required. All configuration is handled through Firebase's generated `firebase_options.dart`. No secrets should be committed to the repository.

## Troubleshooting

- **"No Firebase App"** → Ensure `flutterfire configure` was run and firebase_options.dart is imported
- **Permission denied on Firestore** → Deploy security rules or check user role
- **Images not loading** → Ensure Firebase Storage rules are deployed
- **Build errors after pub get** → Run `flutter clean && flutter pub get`
