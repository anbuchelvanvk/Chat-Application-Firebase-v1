import 'dart:async';
import 'package:flutter/material.dart';
import '../services/user_service.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _service = UserService();

  Timer? _debounce;
  bool loading = false;
  bool openingChat = false;

  List<Map<String, dynamic>> results = [];

  // ============================================================
  // 🔍 SEARCH (DEBOUNCED)
  // ============================================================
  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();

    _debounce?.cancel();

    if (query.length < 2) {
      setState(() {
        loading = false;
        results = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => loading = true);

      try {
        final data = await _service.searchUsers(query);
        if (!mounted) return;

        setState(() {
          results = data;
          loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          loading = false;
          results = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F13),
      appBar: AppBar(
        title: const Text('New Chat'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search username',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF1A1A1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 📋 RESULTS
          Expanded(
            child: _searchCtrl.text.trim().length < 2
                ? const Center(
                    child: Text(
                      'Type at least 2 letters',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : loading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                ? const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final user = results[i];
                      final username = user['username'];

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1F),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7C6EFF),
                            child: Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            '@$username',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: user['verified'] == true
                              ? const Icon(
                                  Icons.verified,
                                  color: Color(0xFF4F9DFF),
                                  size: 18,
                                )
                              : null,
                          onTap: openingChat
                              ? null
                              : () async {
                                  setState(() => openingChat = true);

                                  try {
                                    final chatId = await _service
                                        .createOrGetChat(user['uid']);

                                    if (!mounted) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          chatId: chatId,
                                          peerName: username,
                                          peerUid: user['uid'],
                                          peerVerified:
                                              user['verified'] == true,
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => openingChat = false);
                                    }
                                  }
                                },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
