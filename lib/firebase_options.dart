// Firebase yapılandırması: Firebase konsolundaki google-services.json ve
// GoogleService-Info.plist dosyalarından üretildi. Buradaki API anahtarları
// gizli değildir; projeyi tanıtır. Erişim App Check ile korunur.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

abstract final class DefaultFirebaseOptions {
  /// Firebase'in desteklendiği platformda seçenekler; diğerlerinde null
  /// (uygulama Firebase olmadan, kendi anahtarıyla ya da çevrimdışı çalışır).
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyA7Rla-L9KY7xG_Oftxgt32VHU3qGle4iI',
    appId: '1:554702315101:android:18c3003a4dbf95fe65b7b4',
    messagingSenderId: '554702315101',
    projectId: 'paceora-0',
    storageBucket: 'paceora-0.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyC2F9zbnjxwbUD5-y5tuB-w9xgW8jlgkGI',
    appId: '1:554702315101:ios:c0ba8129b33d6cea65b7b4',
    messagingSenderId: '554702315101',
    projectId: 'paceora-0',
    storageBucket: 'paceora-0.firebasestorage.app',
    iosBundleId: 'com.paceora.paceora',
  );
}
