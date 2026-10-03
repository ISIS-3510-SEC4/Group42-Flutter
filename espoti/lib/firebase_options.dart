// File generated for Firebase initialization mapped from google-services.json
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB6NKw7hvUSzy4AuAYHAdUNiIMPGqVIWJw',
    appId: '1:1001218826519:web:8cfc83f849d40d34a31752',
    messagingSenderId: '1001218826519',
    projectId: 'moviles-9132d',
    storageBucket: 'moviles-9132d.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6NKw7hvUSzy4AuAYHAdUNiIMPGqVIWJw',
    appId: '1:1001218826519:android:8cfc83f849d40d34a31752',
    messagingSenderId: '1001218826519',
    projectId: 'moviles-9132d',
    storageBucket: 'moviles-9132d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB6NKw7hvUSzy4AuAYHAdUNiIMPGqVIWJw',
    appId: '1:1001218826519:ios:8cfc83f849d40d34a31752',
    messagingSenderId: '1001218826519',
    projectId: 'moviles-9132d',
    storageBucket: 'moviles-9132d.firebasestorage.app',
  );
}
