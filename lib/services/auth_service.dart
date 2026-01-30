import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 🔐 LOGIN WITH EMAIL OR USERNAME
  // ============================================================
  Future<User> signIn({
    required String identifier, // email OR username
    required String password,
  }) async {
    final input = identifier.trim().toLowerCase();
    final pwd = password.trim();

    String email;

    // 📧 EMAIL LOGIN
    if (input.contains('@')) {
      email = input;
    }
    // 🧑 USERNAME LOGIN
    else {
      email = await _emailFromUsername(input);
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: pwd,
    );

    return credential.user!;
  }

  // ============================================================
  // 📧 GET EMAIL FROM USERNAME (SAFE)
  // ============================================================
  Future<String> _emailFromUsername(String username) async {
    final snap = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('USER_NOT_FOUND');
    }

    final data = snap.docs.first.data();
    return data['email'] as String;
  }

  // ============================================================
  // 🆕 SIGN UP (EMAIL + PASSWORD ONLY)
  // ============================================================
  Future<User> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );

    return credential.user!;
  }

  // ============================================================
  // 🚪 SIGN OUT
  // ============================================================
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ============================================================
  // 👤 CURRENT USER
  // ============================================================
  User? get currentUser => _auth.currentUser;
}
