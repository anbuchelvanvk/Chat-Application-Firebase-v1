import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'account_screen.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PingMe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: uid)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load chats'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(
              child: Text(
                'No chats yet\nStart a conversation',
                textAlign: TextAlign.center,
              ),
            );
          }

          // 🔥 Safe manual sort
          chats.sort((a, b) {
            final ta = a['lastUpdated'] as Timestamp?;
            final tb = b['lastUpdated'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final users = List<String>.from(chat['users']);
              final peerId = users.firstWhere((id) => id != uid);

              final unread = (chat['unread_$uid'] ?? 0) as int;
              final lastMessage = (chat['lastMessage'] ?? '').toString();

              return FutureBuilder<DocumentSnapshot>(
                // ✅ FIX: Read from 'users_public' to avoid permission crash
                future: FirebaseFirestore.instance
                    .collection('users_public')
                    .doc(peerId)
                    .get(),
                builder: (_, snap) {
                  if (!snap.hasData || !snap.data!.exists) {
                    return const SizedBox();
                  }

                  final user = snap.data!.data() as Map<String, dynamic>;
                  final username = user['username'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF7C6EFF),
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text('@$username'),
                        const Spacer(),
                        if (unread > 0)
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.red,
                            child: Text(
                              unread.toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chat.id)
                          .update({'unread_$uid': 0});

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: chat.id,
                            peerUid: peerId,
                            peerName: username,
                            peerVerified: user['verified'] == true,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}