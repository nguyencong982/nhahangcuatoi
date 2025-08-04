import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDGdZWZn_RQDA-jrEbUHYvx0rengg9RkYc',
    appId: '1:1096129874429:web:01a32696c47705b03bf194',
    messagingSenderId: '1096129874429',
    projectId: 'tik-clone-f03b1',
    authDomain: 'tik-clone-f03b1.firebaseapp.com',
    storageBucket: 'tik-clone-f03b1.firebasestorage.app',
    measurementId: 'G-DXDX7VRGS8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADDKfWY1s18qVUxr7ghaKK-Zy-6XzjXiA',
    appId: '1:1096129874429:android:797802013c27ac4b3bf194',
    messagingSenderId: '1096129874429',
    projectId: 'tik-clone-f03b1',
    storageBucket: 'tik-clone-f03b1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCHG7EcG0lGmmxGocFEpIfeng_4Q3V902U',
    appId: '1:1096129874429:ios:719d308007f1659e3bf194',
    messagingSenderId: '1096129874429',
    projectId: 'tik-clone-f03b1',
    storageBucket: 'tik-clone-f03b1.firebasestorage.app',
    androidClientId: '1096129874429-lusq7uaeqib7a690ouu9qmrqv6bd47ur.apps.googleusercontent.com',
    iosClientId: '1096129874429-m3a6thn92c4r1i9hn847i20je2jbsaep.apps.googleusercontent.com',
    iosBundleId: 'com.example.menufood',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCHG7EcG0lGmmxGocFEpIfeng_4Q3V902U',
    appId: '1:1096129874429:ios:719d308007f1659e3bf194',
    messagingSenderId: '1096129874429',
    projectId: 'tik-clone-f03b1',
    storageBucket: 'tik-clone-f03b1.firebasestorage.app',
    androidClientId: '1096129874429-lusq7uaeqib7a690ouu9qmrqv6bd47ur.apps.googleusercontent.com',
    iosClientId: '1096129874429-m3a6thn92c4r1i9hn847i20je2jbsaep.apps.googleusercontent.com',
    iosBundleId: 'com.example.menufood',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDGdZWZn_RQDA-jrEbUHYvx0rengg9RkYc',
    appId: '1:1096129874429:web:027e5a09c10dc1dc3bf194',
    messagingSenderId: '1096129874429',
    projectId: 'tik-clone-f03b1',
    authDomain: 'tik-clone-f03b1.firebaseapp.com',
    storageBucket: 'tik-clone-f03b1.firebasestorage.app',
    measurementId: 'G-9G3TYGPSG5',
  );

}