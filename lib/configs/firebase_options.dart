import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseOptionsConfig {
  const FirebaseOptionsConfig._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb || _apiKey.isEmpty || _senderId.isEmpty || _projectId.isEmpty) {
      return null;
    }
    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.android => _appId,
      TargetPlatform.iOS => _iosAppId,
      _ => '',
    };
    if (appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
    );
  }
}
