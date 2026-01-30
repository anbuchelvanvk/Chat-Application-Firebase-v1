import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 🔔 INIT FCM
  // ============================================================
  Future<void> init() async {
    // 📱 Ask permission (iOS + Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🔑 Get FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 🔄 Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': newToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // 📲 FOREGROUND notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  // ============================================================
  // 📲 FOREGROUND HANDLER
  // ============================================================
  void _handleForegroundMessage(RemoteMessage message) {
    if (message.notification == null) return;

    debugPrint('🔔 Foreground notification received');
    debugPrint('Title: ${message.notification!.title}');
    debugPrint('Body: ${message.notification!.body}');

    // OPTIONAL:
    // You can show SnackBar / Dialog / Custom banner here
  }
}
