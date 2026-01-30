import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'username_setup_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool loading = false;

  // ============================================================
  // 🚀 SIGN UP
  // ============================================================
  Future<void> _signup() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.length < 6) {
      _showError('Enter valid email & password (min 6 chars)');
      return;
    }

    if (loading) return;

    setState(() => loading = true);

    try {
      // 🔥 SAFETY: clear any existing session
      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // 👉 FORCE PROFILE SETUP
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UsernameSetupScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'email-already-in-use') {
        _showError('Email already registered');
      } else if (e.code == 'weak-password') {
        _showError('Password too weak');
      } else if (e.code == 'invalid-email') {
        _showError('Invalid email');
      } else {
        _showError('Signup failed');
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Signup failed');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ============================================================
  // ❌ ERROR UI
  // ============================================================
  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 📧 EMAIL
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // 🔑 PASSWORD
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),
            // 🚀 SIGN UP
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : _signup,
                child: loading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Text('Sign up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
