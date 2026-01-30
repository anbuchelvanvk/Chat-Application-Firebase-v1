import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _service = UserService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  String _gender = 'male';
  DateTime? _dob;
  String? _originalUsername; // To detect if username actually changed

  bool _loading = true; // Initial load
  bool _saving = false;
  bool _checkingUser = false;

  String? _usernameError;
  bool _usernameAvailable = true;
  Timer? _debounce;

  final _usernameRegex = RegExp(r'^[a-z0-9_]{3,15}$');

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ============================================================
  // 📥 LOAD DATA
  // ============================================================
  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameCtrl.text = data['name'] ?? '';
        _usernameCtrl.text = data['username'] ?? '';
        _originalUsername = data['username']; // Remember original
        _gender = data['gender'] ?? 'male';

        if (data['dob'] != null) {
          _dob = DateTime.tryParse(data['dob']);
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============================================================
  // 🔍 USERNAME CHECKER (DEBOUNCED)
  // ============================================================
  void _onUsernameChanged(String value) {
    final username = value.trim().toLowerCase();
    _debounce?.cancel();

    // 1. Reset state
    setState(() {
      _usernameError = null;
      _usernameAvailable = false;
    });

    // 2. If same as original, it's valid immediately (no DB check needed)
    if (username == _originalUsername) {
      setState(() => _usernameAvailable = true);
      return;
    }

    // 3. Regex Validation
    if (!_usernameRegex.hasMatch(username)) {
      setState(
        () => _usernameError = 'Lowercase, numbers, _ only (3-15 chars)',
      );
      return;
    }

    // 4. Debounce DB Check
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _checkingUser = true);

      try {
        final isReserved = await _service.isReservedUsername(username);
        final isAvailable = await _service.isUsernameAvailable(username);

        if (!mounted) return;

        setState(() {
          if (isReserved) {
            _usernameError = 'This username is reserved';
            _usernameAvailable = false;
          } else if (!isAvailable) {
            _usernameError = 'Username already taken';
            _usernameAvailable = false;
          } else {
            _usernameError = null;
            _usernameAvailable = true;
          }
        });
      } catch (e) {
        setState(() => _usernameError = 'Check failed. Connection error?');
      } finally {
        if (mounted) setState(() => _checkingUser = false);
      }
    });
  }

  // ============================================================
  // 💾 SAVE EVERYTHING
  // ============================================================
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim().toLowerCase();

    // 🚫 VALIDATION
    if (name.isEmpty) return _showError('Name cannot be empty');
    if (_usernameError != null) return _showError('Please fix username errors');
    if (!_usernameAvailable && username != _originalUsername)
      return _showError('Username not available');
    if (_checkingUser) return; // Wait for check to finish

    setState(() => _saving = true);

    try {
      // 1️⃣ UPDATE USERNAME (If changed)
      if (username != _originalUsername) {
        await _service.updateUsername(uid: _uid, newUsername: username);
      }

      // 2️⃣ UPDATE PROFILE INFO
      await _service.updateProfile(
        uid: _uid,
        name: name,
        gender: _gender,
        dob: _dob?.toIso8601String().split('T').first,
      );

      if (!mounted) return;
      Navigator.pop(context); // ✅ Success
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('USERNAME_TAKEN')) {
        setState(() => _usernameError = 'Username already taken');
      } else if (msg.contains('USERNAME_RESERVED')) {
        setState(() => _usernameError = 'This username is reserved');
      } else {
        _showError('Failed to save changes. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🧑 NAME FIELD
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 20),

                  // 🏷️ USERNAME FIELD
                  TextField(
                    controller: _usernameCtrl,
                    onChanged: _onUsernameChanged,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      helperText: 'Unique ID for others to find you',
                      errorText: _usernameError,
                      suffixIcon: _checkingUser
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : (_usernameAvailable
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🚻 GENDER DROPDOWN
                  DropdownButtonFormField<String>(
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _gender = v);
                    },
                    decoration: const InputDecoration(labelText: 'Gender'),
                  ),
                  const SizedBox(height: 20),

                  // 📅 DOB PICKER
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _dob == null
                          ? 'Select Date of Birth'
                          : 'DOB: ${_dob!.toLocal().toString().split(' ')[0]}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                        initialDate: _dob ?? DateTime(2000),
                      );
                      if (picked != null && mounted) {
                        setState(() => _dob = picked);
                      }
                    },
                  ),

                  const SizedBox(height: 40),

                  // 💾 SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving || _checkingUser ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
