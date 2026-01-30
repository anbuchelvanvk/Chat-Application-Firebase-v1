import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // 🔍 SEARCH USERS (PUBLIC DATA ONLY)
  // ============================================================
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    final snap = await _firestore
        .collection('users_public')
        .orderBy('username')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(10)
        .get();

    final myUid = _auth.currentUser?.uid;

    return snap.docs.where((d) => d.id != myUid).map((d) => d.data()).toList();
  }

  // ============================================================
  // 🔐 USERNAME CHECKS
  // ============================================================
  Future<bool> isUsernameAvailable(String username) async {
    final uname = username.toLowerCase().trim();
    final snap = await _firestore.collection('usernames').doc(uname).get();
    return !snap.exists;
  }

  Future<bool> isReservedUsername(String username) async {
    final uname = username.toLowerCase().trim();
    final snap = await _firestore
        .collection('reserved_usernames')
        .doc(uname)
        .get();
    return snap.exists;
  }

  // ============================================================
  // 🔐 SECURITY ANSWER HASH
  // ============================================================
  String _hashAnswer(String answer, String uid) {
    // ✅ FIX: Use SHA256 to match the Forgot Password screen
    return sha256
        .convert(utf8.encode('${answer.trim().toLowerCase()}::$uid'))
        .toString();
  }

  // ============================================================
  // 👤 CREATE USER WITH PROFILE (ATOMIC & SAFE)
  // ============================================================
  Future<void> createUserWithProfile({
    required String uid,
    required String email,
    required String username,
    required String name,
    required String gender,
    required String? dob,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final uname = username.toLowerCase().trim();

    final userRef = _firestore.collection('users').doc(uid);
    final publicRef = _firestore.collection('users_public').doc(uid);
    final usernameRef = _firestore.collection('usernames').doc(uname);
    final reservedRef = _firestore.collection('reserved_usernames').doc(uname);

    await _firestore.runTransaction((tx) async {
      // 🚫 reserved username
      if ((await tx.get(reservedRef)).exists) {
        throw Exception('USERNAME_RESERVED');
      }

      // 🚫 username already taken
      if ((await tx.get(usernameRef)).exists) {
        throw Exception('USERNAME_TAKEN');
      }

      // 🔒 lock username
      tx.set(usernameRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔐 PRIVATE PROFILE
      tx.set(userRef, {
        'uid': uid,
        'email': email,
        'username': uname,
        'name': name,
        'gender': gender,
        'dob': dob,
        'securityQuestion': securityQuestion,
        'securityAnswerHash': _hashAnswer(securityAnswer, uid),
        'verified': false,
        'online': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🌍 PUBLIC PROFILE (SEARCHABLE)
      // ⚠️ must exist or search WILL FAIL
      tx.set(publicRef, {
        'uid': uid,
        'username': uname,
        'displayName': name, // <-- second field (important)
        'verified': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // ============================================================
  // 🔄 UPDATE USERNAME (ATOMIC)
  // ============================================================
  Future<void> updateUsername({
    required String uid,
    required String newUsername,
  }) async {
    final uname = newUsername.toLowerCase().trim();
    final valid = RegExp(r'^[a-z0-9]{3,15}$').hasMatch(uname);
    if (!valid) throw Exception('INVALID_USERNAME');

    final userRef = _firestore.collection('users').doc(uid);
    final publicRef = _firestore.collection('users_public').doc(uid);
    final newUsernameRef = _firestore.collection('usernames').doc(uname);
    final reservedRef = _firestore.collection('reserved_usernames').doc(uname);

    await _firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('USER_NOT_FOUND');

      final oldUsername = userSnap['username'];
      if (oldUsername == uname) return;

      if ((await tx.get(reservedRef)).exists) {
        throw Exception('USERNAME_RESERVED');
      }

      if ((await tx.get(newUsernameRef)).exists) {
        throw Exception('USERNAME_TAKEN');
      }

      // 🔒 lock new username
      tx.set(newUsernameRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🧹 release old username
      tx.delete(_firestore.collection('usernames').doc(oldUsername));

      // 👤 update private profile
      tx.update(userRef, {
        'username': uname,
        'usernameUpdatedAt': FieldValue.serverTimestamp(),
      });

      // 🌍 update public profile
      tx.update(publicRef, {'username': uname});
    });
  }

  // ============================================================
  // 👤 UPDATE PROFILE (SAFE MERGE)
  // ============================================================
  Future<void> updateProfile({
    required String uid,
    required String name,
    required String gender,
    required String? dob,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'gender': gender,
      'dob': dob,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // keep public display name in sync
    await _firestore.collection('users_public').doc(uid).set({
      'displayName': name,
    }, SetOptions(merge: true));
  }

  // ============================================================
  // 💬 CREATE OR GET CHAT (DETERMINISTIC)
  // ============================================================
  Future<String> createOrGetChat(String peerUid) async {
    final uid = _auth.currentUser!.uid;

    final snap = await _firestore
        .collection('chats')
        .where('users', arrayContains: uid)
        .get();

    for (final doc in snap.docs) {
      final users = List<String>.from(doc['users']);
      if (users.contains(peerUid)) {
        return doc.id;
      }
    }

    final ref = await _firestore.collection('chats').add({
      'users': [uid, peerUid],
      'lastMessage': '',
      'lastUpdated': FieldValue.serverTimestamp(),
      'unread_$uid': 0,
      'unread_$peerUid': 0,
      'typing_$uid': false,
      'typing_$peerUid': false,
    });

    return ref.id;
  }
}
