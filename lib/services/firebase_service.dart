import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Set<String> _allowedRoles = {'Volunteer', 'Organizer'};
  static const String _userLookupCollection = 'user_lookup';

  String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'volunteer') return 'Volunteer';
    if (normalized == 'organizer') return 'Organizer';
    throw Exception('Role must be Volunteer or Organizer.');
  }

  Map<String, dynamic> _buildBaseUserDoc({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String primaryRole,
    bool includeCreatedAt = false,
  }) {
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final cleanPhone = phone.trim();
    final roles = <String>[primaryRole];

    final doc = <String, dynamic>{
      'uid': uid,
      'name': cleanName,
      'email': cleanEmail,
      'phone': cleanPhone,
      'displayName': cleanName,
      'emailLower': cleanEmail.toLowerCase(),
      'nameLower': cleanName.toLowerCase(),
      'role': primaryRole,
      'roles': roles,
      'isVolunteer': roles.contains('Volunteer'),
      'isOrganizer': roles.contains('Organizer'),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (includeCreatedAt) {
      doc['createdAt'] = FieldValue.serverTimestamp();
    }

    return doc;
  }

  Map<String, dynamic> _buildUserLookupDoc(Map<String, dynamic> baseUserDoc) {
    return <String, dynamic>{
      'uid': baseUserDoc['uid'],
      'name': baseUserDoc['name'],
      'displayName': baseUserDoc['displayName'],
      'nameLower': baseUserDoc['nameLower'],
      'email': baseUserDoc['email'],
      'emailLower': baseUserDoc['emailLower'],
      'role': baseUserDoc['role'],
      'roles': baseUserDoc['roles'],
      'isVolunteer': baseUserDoc['isVolunteer'],
      'isOrganizer': baseUserDoc['isOrganizer'],
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _upsertUserLookupDoc({
    required String uid,
    required Map<String, dynamic> baseUserDoc,
    bool includeCreatedAt = false,
  }) {
    final lookupDoc = _buildUserLookupDoc(baseUserDoc);
    if (includeCreatedAt) {
      lookupDoc['createdAt'] = FieldValue.serverTimestamp();
    }

    return _firestore
        .collection(_userLookupCollection)
        .doc(uid)
        .set(lookupDoc, SetOptions(merge: true));
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      final normalizedRole = _normalizeRole(role);
      if (!_allowedRoles.contains(normalizedRole)) {
        throw Exception('Role must be Volunteer or Organizer.');
      }

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      final uid = userCredential.user!.uid;
      final baseUserDoc = _buildBaseUserDoc(
        uid: uid,
        email: email,
        name: name,
        phone: phone,
        primaryRole: normalizedRole,
        includeCreatedAt: true,
      );

      // Save normalized base user data to Firestore.
      await _firestore
          .collection('users')
          .doc(uid)
          .set(baseUserDoc, SetOptions(merge: true));

      // Write a small searchable index for fast lookup by name/email.
      await _upsertUserLookupDoc(
        uid: uid,
        baseUserDoc: baseUserDoc,
        includeCreatedAt: true,
      );

      // Keep editable profile fields in a separate collection.
      await _firestore.collection('user_profiles').doc(uid).set({
        'name': name,
        'phone': phone,
        'photoUrl': '',
        'bio': '',
        'address': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return userCredential;
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        'FirebaseService.signUp auth error: ${e.code} ${e.message}\n$st',
      );
      if (e.code == 'email-already-in-use') {
        throw Exception(
          'This email is already registered. One email can only have one role. Use a different email for a different role account.',
        );
      }
      rethrow;
    } catch (e, st) {
      // Log the full error to console for debugging.
      // The UI will show the user-friendly message.
      debugPrint('FirebaseService.signUp error: $e\n$st');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Get editable user profile data from dedicated profile collection.
  Future<Map<String, dynamic>?> getUserProfileData(String uid) async {
    try {
      final doc = await _firestore.collection('user_profiles').doc(uid).get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to get user profile data: $e');
    }
  }

  // Merge auth/base user data with profile collection (profile values override).
  Future<Map<String, dynamic>> getMergedUserData(String uid) async {
    final base = await getUserData(uid) ?? <String, dynamic>{};
    final profile = await getUserProfileData(uid) ?? <String, dynamic>{};
    return {...base, ...profile};
  }

  // Live stream of base user document data.
  Stream<Map<String, dynamic>> streamUserData(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data() ?? <String, dynamic>{});
  }

  // Update role for the currently signed-in user.
  Future<void> updateCurrentUserRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No signed-in user.');
    }

    final normalizedRole = _normalizeRole(role);
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? const <String, dynamic>{};
    final baseUserDoc = _buildBaseUserDoc(
      uid: user.uid,
      email: (data['email'] ?? user.email ?? '').toString(),
      name: (data['name'] ?? user.displayName ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      primaryRole: normalizedRole,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(baseUserDoc, SetOptions(merge: true));

    await _upsertUserLookupDoc(uid: user.uid, baseUserDoc: baseUserDoc);
  }

  // Query user lookup index by name/email prefix (lowercase input recommended).
  Future<List<Map<String, dynamic>>> searchUsersForLookup(
    String query, {
    int limit = 20,
  }) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];

    final byName = await _firestore
        .collection(_userLookupCollection)
        .orderBy('nameLower')
        .startAt([term])
        .endAt(['$term\uf8ff'])
        .limit(limit)
        .get();

    final byEmail = await _firestore
        .collection(_userLookupCollection)
        .orderBy('emailLower')
        .startAt([term])
        .endAt(['$term\uf8ff'])
        .limit(limit)
        .get();

    final merged = <String, Map<String, dynamic>>{};
    for (final doc in byName.docs) {
      merged[doc.id] = {'id': doc.id, ...doc.data()};
    }
    for (final doc in byEmail.docs) {
      merged[doc.id] = {'id': doc.id, ...doc.data()};
    }

    return merged.values.toList();
  }

  // Stream organizer-created events for volunteer discovery.
  Stream<List<Map<String, dynamic>>> streamOrganizerEvents() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      events.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate();
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return events;
    });
  }

  // Stream events joined by the current user.
  Stream<List<Map<String, dynamic>>> streamMyJoinedEvents() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    return _firestore
        .collection('events')
        .where('participantIds', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

          DateTime? toDate(dynamic value) {
            if (value is Timestamp) return value.toDate();
            if (value is DateTime) return value;
            if (value is String) return DateTime.tryParse(value);
            return null;
          }

          events.sort((a, b) {
            final aDate = toDate(a['eventDate'] ?? a['date'] ?? a['startDate']);
            final bDate = toDate(b['eventDate'] ?? b['date'] ?? b['startDate']);
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

          return events;
        });
  }

  // Join an event as the current volunteer.
  Future<void> joinEvent({required String eventId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please login to join events.');
    }

    final eventRef = _firestore.collection('events').doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) {
        throw Exception('Event not found.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final participantIds = List<String>.from(
        (data['participantIds'] as List<dynamic>? ?? const []).map(
          (e) => e.toString(),
        ),
      );

      if (!participantIds.contains(user.uid)) {
        participantIds.add(user.uid);
      }

      transaction.update(eventRef, {
        'participantIds': participantIds,
        'participantsCount': participantIds.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Leave a joined event for the current volunteer.
  Future<void> leaveEvent({required String eventId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please login to manage events.');
    }

    final eventRef = _firestore.collection('events').doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) {
        throw Exception('Event not found.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final participantIds = List<String>.from(
        (data['participantIds'] as List<dynamic>? ?? const []).map(
          (e) => e.toString(),
        ),
      );
      final checkedInIds = List<String>.from(
        (data['checkedInIds'] as List<dynamic>? ?? const []).map(
          (e) => e.toString(),
        ),
      );
      final awardedParticipantIds = List<String>.from(
        (data['awardedParticipantIds'] as List<dynamic>? ?? const []).map(
          (e) => e.toString(),
        ),
      );
      final impactPointsRaw =
          data['impactPoints'] ?? data['points'] ?? data['rewardPoints'];
      final impactPoints = impactPointsRaw is num
          ? impactPointsRaw.toInt()
          : int.tryParse(impactPointsRaw?.toString() ?? '') ?? 0;

      final wasAwarded = awardedParticipantIds.contains(user.uid);
      final shouldReversePoints = wasAwarded && impactPoints > 0;

      participantIds.removeWhere((id) => id == user.uid);
      checkedInIds.removeWhere((id) => id == user.uid);
      awardedParticipantIds.removeWhere((id) => id == user.uid);

      final userRef = _firestore.collection('users').doc(user.uid);
      final userSnap = await transaction.get(userRef);
      final userData = userSnap.data() ?? <String, dynamic>{};
      final currentPointsRaw =
          userData['impactPoints'] ??
          userData['totalPoints'] ??
          userData['rewardPoints'] ??
          userData['points'];
      final currentPoints = currentPointsRaw is num
          ? currentPointsRaw.toInt()
          : int.tryParse(currentPointsRaw?.toString() ?? '') ?? 0;

      final userUpdates = <String, dynamic>{
        'participationStatusByEvent.$eventId': FieldValue.delete(),
        'attendanceVerifiedAtByEvent.$eventId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (shouldReversePoints) {
        final updatedPoints = (currentPoints - impactPoints).clamp(
          0,
          1000000000,
        );
        userUpdates['impactPoints'] = updatedPoints;
        userUpdates['totalPoints'] = updatedPoints;
        userUpdates['rewardPoints'] = updatedPoints;
        userUpdates['points'] = updatedPoints;
      }

      transaction.set(userRef, userUpdates, SetOptions(merge: true));

      transaction.update(eventRef, {
        'participantIds': participantIds,
        'checkedInIds': checkedInIds,
        'awardedParticipantIds': awardedParticipantIds,
        'participantsCount': participantIds.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> resetUserStats(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'impactPoints': FieldValue.delete(),
        'totalPoints': FieldValue.delete(),
        'rewardPoints': FieldValue.delete(),
        'points': FieldValue.delete(),
        'attendanceVerifiedAtByEvent': FieldValue.delete(),
        'participationStatusByEvent': FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Failed to reset user stats: $e');
    }
  }
}
