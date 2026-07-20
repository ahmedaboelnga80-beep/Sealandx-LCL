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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_SealandX_Web_ApiKey_Placeholder',
    appId: '1:100000000000:web:sealandx_lcl_web',
    messagingSenderId: '100000000000',
    projectId: 'sealandx-lcl-scans',
    authDomain: 'sealandx-lcl-scans.firebaseapp.com',
    storageBucket: 'sealandx-lcl-scans.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_SealandX_Android_ApiKey_Placeholder',
    appId: '1:100000000000:android:sealandx_lcl_android',
    messagingSenderId: '100000000000',
    projectId: 'sealandx-lcl-scans',
    storageBucket: 'sealandx-lcl-scans.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_SealandX_iOS_ApiKey_Placeholder',
    appId: '1:100000000000:ios:sealandx_lcl_ios',
    messagingSenderId: '100000000000',
    projectId: 'sealandx-lcl-scans',
    storageBucket: 'sealandx-lcl-scans.appspot.com',
    iosBundleId: 'com.sealandx.lcl.sealandxLcl',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA_SealandX_macOS_ApiKey_Placeholder',
    appId: '1:100000000000:ios:sealandx_lcl_ios',
    messagingSenderId: '100000000000',
    projectId: 'sealandx-lcl-scans',
    storageBucket: 'sealandx-lcl-scans.appspot.com',
    iosBundleId: 'com.sealandx.lcl.sealandxLcl',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA_SealandX_Windows_ApiKey_Placeholder',
    appId: '1:100000000000:web:sealandx_lcl_web',
    messagingSenderId: '100000000000',
    projectId: 'sealandx-lcl-scans',
    authDomain: 'sealandx-lcl-scans.firebaseapp.com',
    storageBucket: 'sealandx-lcl-scans.appspot.com',
  );
}
