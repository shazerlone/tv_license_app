import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config.dart';
import '../firebase_options.dart';
import '../models/app_notification.dart';
import '../state/app_state.dart';
import 'backend_api.dart';

/// FCM background handler — must be a top-level entry point. We don't need to do
/// anything here (the OS shows the notification); it just has to exist so
/// background messages are delivered.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // No-op: the system tray notification is rendered by the OS.
}

/// Wires Firebase Cloud Messaging: initializes Firebase, asks for permission,
/// registers the device token with the backend (POST /devices), and surfaces
/// foreground messages into the in-app notification center.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  AppState? _store;
  String? _token;
  bool _started = false;

  /// Call once after login, with the shared AppState. Safe to call again.
  Future<void> start(AppState store) async {
    _store = store;
    if (_started || !kUseBackend) return;
    _started = true;
    try {
      // main() already initializes Firebase; only do it here if that was skipped.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      final fm = FirebaseMessaging.instance;

      await fm.requestPermission(alert: true, badge: true, sound: true);
      // Show heads-up notifications while the app is foregrounded (iOS).
      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      _token = await fm.getToken();
      if (_token != null) await _register(_token!);

      // Re-register if the token rotates.
      fm.onTokenRefresh.listen((t) {
        _token = t;
        _register(t);
      });

      // Foreground messages → push into the in-app notification center.
      FirebaseMessaging.onMessage.listen(_onForeground);
    } catch (_) {
      // Firebase not configured on this build / no network — ignore silently.
    }
  }

  Future<void> _register(String token) async {
    try {
      await BackendApi.registerDevice(platform: Platform.isIOS ? 'ios' : 'android', token: token, appVersion: kBuildSha);
    } catch (_) {/* backend will get it on next refresh */}
  }

  void _onForeground(RemoteMessage m) {
    final store = _store;
    if (store == null) return;
    final n = m.notification;
    final data = m.data;
    final title = n?.title ?? data['title']?.toString() ?? 'Millimore';
    final body = n?.body ?? '';
    store.pushNotification(AppNotification.fromJson({
      'id': m.messageId ?? '${DateTime.now().microsecondsSinceEpoch}',
      'type': data['type'],
      'title': title,
      'body': body,
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
    }));
  }

  /// Unregister on logout so a signed-out device stops receiving pushes.
  Future<void> stop() async {
    final t = _token;
    if (t != null) {
      try {
        await BackendApi.removeDevice(t);
      } catch (_) {}
    }
    _started = false;
  }
}
