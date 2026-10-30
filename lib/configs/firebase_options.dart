import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseOptionsConfig {
  const FirebaseOptionsConfig._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const vapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static String get workerPath => Uri(
    path: 'push/firebase-messaging-sw.js',
    queryParameters: {
      'apiKey': _apiKey,
      'appId': webAppId,
      'messagingSenderId': _senderId,
      'projectId': _projectId,
      'authDomain': authDomain,
    },
  ).toString();

  static FirebaseOptions? get currentPlatform {
    if (_apiKey.isEmpty || _senderId.isEmpty || _projectId.isEmpty) {
      return null;
    }
    final appId = kIsWeb
        ? webAppId
        : switch (defaultTargetPlatform) {
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
      authDomain: kIsWeb ? authDomain : null,
    );
  }
}
