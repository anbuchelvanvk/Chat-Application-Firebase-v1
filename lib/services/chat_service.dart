import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  // ============================================================
  // ✉️ SEND MESSAGE
  // ============================================================
  Future<void> sendMessage({
    required String chatId,
    required String text,
    required String peerUid,
  }) async {
    final msg = text.trim();
    if (msg.isEmpty) return;

    final chatRef = _firestore.collection('chats').doc(chatId);

    // 🔹 add message
    await chatRef.collection('messages').add({
      'text': msg,
      'senderId': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveredTo': [],
      'seenBy': [],
    });

    // 🔹 update chat for chat list
    await chatRef.set({
      'users': [_uid, peerUid],
      'lastMessage': text.trim(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'unread_$peerUid': FieldValue.increment(1),
      'typing_${_uid}': false,
    }, SetOptions(merge: true));
  }

  // ============================================================
  // 📡 STREAM MESSAGES
  // ============================================================
  Stream<QuerySnapshot> streamMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ============================================================
  // ✔ MARK DELIVERED
  // ============================================================
  Future<void> markDelivered(String chatId) async {
    final snap = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _uid)
        .get();

    for (final d in snap.docs) {
      d.reference.update({
        'deliveredTo': FieldValue.arrayUnion([_uid]),
      });
    }
  }

  // ============================================================
  // 👁️ MARK SEEN
  // ============================================================
  Future<void> markSeen(String chatId) async {
    final uid = _auth.currentUser!.uid;
    final chatRef = _firestore.collection('chats').doc(chatId);

    final snap = await chatRef
        .collection('messages')
        .where('senderId', isNotEqualTo: uid)
        .get();

    for (final d in snap.docs) {
      d.reference.update({
        'seenBy': FieldValue.arrayUnion([uid]),
      });
    }

    // ✅ reset unread badge
    await chatRef.update({'unread_$uid': 0});
  }

  // ============================================================
  // ⌨️ TYPING
  // ============================================================
  Future<void> setTyping(String chatId, bool typing) async {
    await _firestore.collection('chats').doc(chatId).update({
      'typing_${_uid}': typing,
    });
  }

  // ============================================================
  // 📥 CHAT LIST
  // ============================================================
  Stream<QuerySnapshot> streamChats() {
    return _firestore
        .collection('chats')
        .where('users', arrayContains: _uid)
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }
}
