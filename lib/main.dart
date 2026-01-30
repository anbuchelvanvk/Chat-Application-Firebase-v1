import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'theme.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/username_setup_screen.dart';

// Services
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const PingMeApp());
}

class PingMeApp extends StatefulWidget {
  const PingMeApp({super.key});

  @override
  State<PingMeApp> createState() => _PingMeAppState();
}

/// ------------------------------------------------------------
/// 🌐 APP LIFECYCLE (ONLINE / OFFLINE + FCM INIT)
/// ------------------------------------------------------------
class _PingMeAppState extends State<PingMeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔔 INIT PUSH NOTIFICATIONS (NO await here)
    NotificationService.instance.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ------------------------------------------------------------
  // 🟢 ONLINE / 🔴 OFFLINE HANDLING
  // ------------------------------------------------------------
  // ------------------------------------------------------------
  // 🟢 ONLINE / 🔴 OFFLINE HANDLING
  // ------------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final privateRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final publicRef = FirebaseFirestore.instance
        .collection('users_public')
        .doc(user.uid); // ✅ ADD THIS

    final snap = await privateRef.get();

    // 🚫 DO NOTHING if profile not created yet
    if (!snap.exists || !snap.data()!.containsKey('username')) return;

    final isOnline = state == AppLifecycleState.resumed;
    final timestamp = FieldValue.serverTimestamp();

    final updateData = {'online': isOnline, 'lastSeen': timestamp};

    // ✅ FIX: Update both Private and Public profiles
    // ✅ FIX: Wrap in try-catch to prevent freezing if permissions fail
    try {
      await privateRef.update(updateData);
      await publicRef.update(updateData);
    } catch (e) {
      print("Failed to update status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PingMe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AuthGate(),
    );
  }
}

/// ------------------------------------------------------------
/// 🔐 AUTH GATE
/// ------------------------------------------------------------
/// Flow:
/// 1️⃣ Not logged in → LoginScreen
/// 2️⃣ Logged in, no profile → UsernameSetupScreen
/// 3️⃣ Logged in + profile → ChatListScreen
/// ------------------------------------------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        // ⏳ Checking auth
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ NOT LOGGED IN
        if (!authSnap.hasData) {
          return const LoginScreen();
        }

        final uid = authSnap.data!.uid;

        // 🔍 Check profile existence
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const UsernameSetupScreen();
            }

            final data = userSnap.data!.data() as Map<String, dynamic>?;

            if (data == null || !data.containsKey('username')) {
              return const UsernameSetupScreen();
            }

            // ✅ READY
            return const ChatListScreen();
          },
        );
      },
    );
  }
}
