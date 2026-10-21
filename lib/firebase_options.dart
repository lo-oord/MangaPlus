// Firebase configuration for the MangaPlus Android app.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-yhgkPpHWOFqg4ha--UCwj6oYQ10i7Bk',
    appId: '1:479859476328:android:be0325ec9db14f11e478dd',
    messagingSenderId: '479859476328',
    projectId: 'mangaplus-c98f0',
    storageBucket: 'mangaplus-c98f0.firebasestorage.app',
  );
}
