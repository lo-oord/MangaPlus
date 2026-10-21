// Firebase configuration for the Android app.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBjcABBM7bqu9DtdvbeGbx8mhBragfj_5I',
    appId: '1:91808450023:android:14dfcb372debccaf6ce942',
    messagingSenderId: '91808450023',
    projectId: 'komikaze',
    storageBucket: 'komikaze.firebasestorage.app',
  );
}
