import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/user_service.dart';
import 'chat_list_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _securityAnswerCtrl = TextEditingController();

  final _service = UserService();

  Timer? _debounce;
  bool checking = false;
  bool submitting = false;
  bool? available;
  String? error;

  String gender = 'male';
  DateTime? dob;

  // 🔐 Security question
  final List<String> securityQuestions = const [
    'What is your favourite colour?',
    'What is your mother’s name?',
    'What was your first school?',
    'What is your favourite food?',
  ];
  String selectedQuestion = 'What is your favourite colour?';

  final _usernameRegex = RegExp(r'^[a-z0-9]{3,15}$');

  // ============================================================
  // 🔍 USERNAME CHECK (DEBOUNCED)
  // ============================================================
  void _onUsernameChanged(String value) {
    final username = value.trim().toLowerCase();

    _debounce?.cancel();
    setState(() {
      available = null;
      error = null;
    });

    if (!_usernameRegex.hasMatch(username)) {
      setState(() {
        error = 'Only lowercase letters & numbers (3–15 chars)';
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => checking = true);

      try {
        final isFree = await _service.isUsernameAvailable(username);
        final isReserved = await _service.isReservedUsername(username);

        if (!mounted) return;

        setState(() {
          if (isReserved) {
            available = false;
            error = 'This username is reserved';
          } else {
            available = isFree;
            error = isFree ? null : 'Username already taken';
          }
          checking = false;
        });
      } catch (e) {
        // ✅ FIX: Print the ACTUAL error to the console
        debugPrint("USERNAME CHECK ERROR: $e");

        if (!mounted) return;
        setState(() {
          checking = false;
          // ✅ FIX: Show the specific error on UI temporarily
          error = 'Error: $e';
        });
      }
    });
  }

  // ============================================================
  // 🚀 SUBMIT PROFILE
  // ============================================================
  Future<void> _submit() async {
    if (submitting || checking) return;

    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim().toLowerCase();
    final answer = _securityAnswerCtrl.text.trim();

    if (name.isEmpty || dob == null || available != true || answer.isEmpty) {
      _showError('Please complete all fields correctly');
      return;
    }

    setState(() => submitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('NO_AUTH');

      await _service.createUserWithProfile(
        uid: user.uid,
        email: user.email!,
        username: username,
        name: name,
        gender: gender,
        dob: dob!.toIso8601String().split('T').first,
        securityQuestion: selectedQuestion,
        securityAnswer: answer,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
        (_) => false,
      );
    } catch (e) {
      // ✅ FIX: Print submit errors too
      debugPrint("SUBMIT ERROR: $e");

      if (!mounted) return;

      final msg = e.toString();
      if (msg.contains('USERNAME_TAKEN')) {
        _showError('Username already taken');
      } else if (msg.contains('USERNAME_RESERVED')) {
        _showError('This username is reserved');
      } else {
        _showError('Account creation failed: $e');
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

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
    _debounce?.cancel();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _securityAnswerCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          // ✅ Added ScrollView to prevent overflow
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),

              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  dob == null
                      ? 'Select date of birth'
                      : dob!.toLocal().toString().split(' ')[0],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                    initialDate: DateTime(2000),
                  );
                  if (picked != null && mounted) {
                    setState(() => dob = picked);
                  }
                },
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: gender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => gender = v!),
                decoration: const InputDecoration(labelText: 'Gender'),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _usernameCtrl,
                onChanged: _onUsernameChanged,
                decoration: InputDecoration(
                  labelText: 'Username',
                  suffixIcon: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : available == true
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : available == false
                      ? const Icon(Icons.cancel, color: Colors.red)
                      : null,
                ),
              ),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedQuestion,
                items: securityQuestions
                    .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                    .toList(),
                onChanged: (v) => setState(() => selectedQuestion = v!),
                decoration: const InputDecoration(
                  labelText: 'Security question',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _securityAnswerCtrl,
                decoration: const InputDecoration(labelText: 'Your answer'),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: submitting || checking ? null : _submit,
                  child: submitting
                      ? const CircularProgressIndicator()
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
