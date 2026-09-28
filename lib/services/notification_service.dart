import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../repositories/repository.dart';

/// Bridges Firebase Cloud Messaging into the app. In demo mode this service is
/// inert (notifications are simulated by the in-memory repository).
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _foreground = StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onForegroundMessage => _foreground.stream;

  StreamSubscription? _sub;

  Future<void> init(IRepository repo) async {
    if (repo.isDemo) return;
    await _requestPermission();
    final sub = FirebaseMessaging.onMessage.listen((message) {
      if (!_foreground.isClosed) _foreground.add(message);
    });
    _sub = sub;
    final token = await _messaging.getToken();
    if (token != null) {
      await repo.saveFcmToken(token);
    }
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _foreground.close();
  }
}