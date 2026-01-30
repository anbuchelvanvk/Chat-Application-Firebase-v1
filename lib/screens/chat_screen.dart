import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String peerUid;
  final String peerName;
  final bool peerVerified;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.peerUid,
    required this.peerName,
    required this.peerVerified,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final _msgCtrl = TextEditingController();
  final _chatService = ChatService();

  bool _typing = false;
  bool _marked = false;

  DocumentReference get _chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

  // ============================================================
  // 🔁 LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'unread_$uid': 0,
    });
    ChatService().markDelivered(widget.chatId);
    ChatService().markSeen(widget.chatId);

    // ✅ mark delivered & seen ONCE
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_marked) {
        _marked = true;
        await _chatService.markDelivered(widget.chatId);
        await _chatService.markSeen(widget.chatId);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setTyping(false);
    _msgCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // ⌨️ TYPING
  // ============================================================
  Future<void> _setTyping(bool value) async {
    if (_typing == value) return;
    _typing = value;
    await _chatService.setTyping(widget.chatId, value);
  }

  // ============================================================
  // 💬 SEND
  // ============================================================
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    await _setTyping(false);

    await _chatService.sendMessage(
      chatId: widget.chatId,
      text: text,
      peerUid: widget.peerUid,
    );
  }

  // ============================================================
  // ✔ MESSAGE TICKS
  // ============================================================
  Widget _ticks(Map<String, dynamic> data, bool isMe) {
    if (!isMe) return const SizedBox();

    final deliveredTo = List<String>.from(data['deliveredTo'] ?? []);
    final seenBy = List<String>.from(data['seenBy'] ?? []);

    if (seenBy.contains(widget.peerUid)) {
      return const Icon(
        Icons.done_all,
        size: 14,
        color: Colors.lightBlueAccent,
      );
    }

    if (deliveredTo.contains(widget.peerUid)) {
      return const Icon(Icons.done_all, size: 14, color: Colors.white54);
    }

    return const Icon(Icons.check, size: 14, color: Colors.white54);
  }

  // ============================================================
  // 🕒 TIME
  // ============================================================
  String _time(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _lastSeen(Map<String, dynamic> user) {
    // 1. Check Online Status
    if (user['online'] == true) return 'Online';

    // 2. Check Timestamp
    final ts = user['lastSeen'] as Timestamp?;
    if (ts == null) return 'Online';

    final dt = ts.toDate();
    final now = DateTime.now();
    final time = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

    // 3. Check if Today
    final isToday =
        now.day == dt.day && now.month == dt.month && now.year == dt.year;

    if (isToday) {
      return 'Last seen today at $time';
    }

    return 'Last seen on ${dt.day}/${dt.month}';
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F13),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _chatRef.snapshots(),
        builder: (_, chatSnap) {
          final chat = chatSnap.data?.data() as Map<String, dynamic>?;
          final peerTyping = chat?['typing_${widget.peerUid}'] == true;

          return Column(
            children: [
              // ================= HEADER (Status Bar) =================
              // ================= HEADER (Status Bar) =================
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users_public') // Listening to public profile
                    .doc(widget.peerUid)
                    .snapshots(),
                builder: (_, snap) {
                  final user = snap.data?.data() as Map<String, dynamic>?;

                  String statusText = '';
                  Color statusColor = Colors.white54;

                  // 🟢 LOGIC: Determine Status
                  if (peerTyping) {
                    statusText = 'Typing…';
                    statusColor = const Color(0xFF7C6EFF);
                  } else if (user != null) {
                    // ✅ FIX: We now CALL the helper function
                    statusText = _lastSeen(user);

                    if (statusText == 'Online') {
                      statusColor = Colors.greenAccent;
                    }
                  }

                  return ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 56, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const BackButton(color: Colors.white),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF7C6EFF),
                              child: Text(
                                widget.peerName.isNotEmpty
                                    ? widget.peerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.peerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // 👇 This Text widget displays the status
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                    fontWeight: peerTyping
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ================= MESSAGES =================
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.streamMessages(widget.chatId),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final msgs = snap.data!.docs;

                    if (msgs.isEmpty) {
                      return Center(
                        child: Text(
                          'Say hi to ${widget.peerName} 👋',
                          style: const TextStyle(color: Colors.white24),
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final data = m.data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == uid;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF7C6EFF)
                                  : const Color(0xFF1A1A1F),
                              borderRadius: BorderRadius.circular(18).copyWith(
                                bottomRight: isMe
                                    ? const Radius.circular(4)
                                    : null,
                                bottomLeft: !isMe
                                    ? const Radius.circular(4)
                                    : null,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  data['text'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _time(data['createdAt']),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white54,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _ticks(data, isMe),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ================= INPUT =================
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF0E0F13),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1F),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          onChanged: (v) => _setTyping(v.trim().isNotEmpty),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: const CircleAvatar(
                        backgroundColor: Color(0xFF7C6EFF),
                        radius: 22,
                        child: Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
