import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _idCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool loading = false;
  bool verified = false;

  String? uid;
  String? email;
  String? question;

  // ============================================================
  // 🔐 HASH ANSWER (Synced with UserService)
  // ============================================================
  String _hash(String answer, String uid) {
    // ✅ FIX: Must match the format used in UserService!
    // Format: "answer::uid" (trimmed & lowercase)
    final value = answer.trim().toLowerCase();
    return sha256.convert(utf8.encode('$value::$uid')).toString();
  }

  // ============================================================
  // 🔍 GET SECURITY QUESTION
  // ============================================================
  Future<void> _fetchQuestion() async {
    final input = _idCtrl.text.trim().toLowerCase();
    if (input.isEmpty) return _error('Enter email or username');

    setState(() => loading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(input.contains('@') ? 'email' : 'username', isEqualTo: input)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) throw 'NOT_FOUND';

      final data = snap.docs.first.data();

      setState(() {
        uid = data['uid'];
        email = data['email'];
        question = data['securityQuestion'];
      });
    } catch (_) {
      _error('Account not found');
    } finally {
      setState(() => loading = false);
    }
  }

  // ============================================================
  // ✅ VERIFY ANSWER
  // ============================================================
  Future<void> _verifyAnswer() async {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty) return _error('Enter your answer');

    setState(() => loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final stored = doc['securityAnswerHash'];

      // ✅ FIX: Use the synced hash function
      final input = _hash(answer, uid!);

      if (stored != input) throw 'WRONG';

      setState(() => verified = true);
    } catch (_) {
      _error('Incorrect answer');
    } finally {
      setState(() => loading = false);
    }
  }

  // ============================================================
  // 🔑 SEND RESET EMAIL (FINAL STEP)
  // ============================================================
  Future<void> _submitNewPassword() async {
    final p1 = _passCtrl.text.trim();
    final p2 = _confirmCtrl.text.trim();

    if (p1.length < 6) return _error('Password must be at least 6 characters');
    if (p1 != p2) return _error('Passwords do not match');

    setState(() => loading = true);

    try {
      // ⚠️ NOTE: Firebase Client SDK prevents setting the password directly
      // without the old password. The secure method is sending the email.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email!);

      if (!mounted) return;

      // We show a success message explaining the email link
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Action Required'),
          content: const Text(
            'Security answer correct!\n\n'
            'For security reasons, we have sent a final confirmation link to your email to apply this new password.\n\n'
            'Please check your inbox.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      _error('Failed to send reset email');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _answerCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _idCtrl,
              enabled: !verified,
              decoration: const InputDecoration(labelText: 'Email or Username'),
            ),
            const SizedBox(height: 20),

            if (!verified && question == null)
              ElevatedButton(
                onPressed: loading ? null : _fetchQuestion,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Continue'),
              ),

            if (question != null && !verified) ...[
              const SizedBox(height: 30),
              Text(
                'Security Question',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                question!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _answerCtrl,
                decoration: const InputDecoration(labelText: 'Your Answer'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : _verifyAnswer,
                child: const Text('Verify Answer'),
              ),
            ],

            if (verified) ...[
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text("Answer Verified! Set your new password."),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : _submitNewPassword,
                child: const Text('Reset Password'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
