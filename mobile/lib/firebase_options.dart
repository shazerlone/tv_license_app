// Firebase configuration for Millimore, derived from the project's
// GoogleService-Info.plist (iOS) and google-services.json (Android) — kept in
// Dart so the app initializes Firebase without needing the native config files
// wired into the regenerated Xcode/Gradle projects on each CI build.
//
// Project: millimore-31a87
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase web is not configured for Millimore.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        // Fall back to iOS options on other platforms we don't ship.
        return ios;
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCgdDw1YCX6OszV82x9PZpjSDsh7oZoF3U',
    appId: '1:620603015906:ios:f038e2a711c20b6ff094bb',
    messagingSenderId: '620603015906',
    projectId: 'millimore-31a87',
    storageBucket: 'millimore-31a87.firebasestorage.app',
    iosBundleId: 'com.millimore.millimore',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAYMF2OVTFI-mVNq8Qslthcq8-31Uyl5iA',
    appId: '1:620603015906:android:073cbd7d5363e145f094bb',
    messagingSenderId: '620603015906',
    projectId: 'millimore-31a87',
    storageBucket: 'millimore-31a87.firebasestorage.app',
  );
}
