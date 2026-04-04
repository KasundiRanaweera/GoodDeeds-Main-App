import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/firebase_service.dart';
import '../welcome_screen.dart';
import 'community_screen.dart';
import 'discover_events_screen.dart';
import 'edit_profile_screen.dart';
import 'myfriends_screen.dart';
import 'my_events_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

Future<String> _uploadPostImage(XFile imageFile, String userId) async {
  final bytes = await imageFile.readAsBytes();
  final lowerName = imageFile.name.toLowerCase();
  final ext = lowerName.contains('.') ? lowerName.split('.').last : 'jpg';
  final contentType = switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };

  final ref = FirebaseStorage.instance.ref().child(
    'events/$userId/posts/${DateTime.now().millisecondsSinceEpoch}.$ext',
  );
  await ref.putData(bytes, SettableMetadata(contentType: contentType));
  return ref.getDownloadURL();
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _signOut() async {
    try {
      await _firebaseService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to sign out: $e')));
    }
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic date = value?.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _relativeDate(DateTime? date) {
    if (date == null) return 'Unknown time';
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    if (diff.inDays > 0) {
      return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
    }
    if (diff.inHours > 0) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inMinutes > 0) {
      return diff.inMinutes == 1
          ? '1 minute ago'
          : '${diff.inMinutes} minutes ago';
    }
    return 'Just now';
  }

  String _formatJoinedDate(DateTime? date) {
    if (date == null) return 'Joined recently';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Joined ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _openCreatePostScreen(
    Map<String, dynamic> profileData,
    bool isDark,
  ) async {
    final currentUser = _firebaseService.currentUser;
    if (currentUser == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _CreatePostScreen(
          profileData: profileData,
          isDark: isDark,
          firebaseService: _firebaseService,
          imagePicker: _imagePicker,
        ),
      ),
    );
  }

  IconData _activityIcon(Map<String, dynamic> event) {
    final title = _asString(
      event['title'] ??
          event['eventName'] ??
          event['name'] ??
          event['category'],
    ).toLowerCase();

    if (title.contains('tree') ||
        title.contains('park') ||
        title.contains('plant')) {
      return Icons.park;
    }
    if (title.contains('clean') || title.contains('beach')) {
      return Icons.delete_sweep;
    }
    if (title.contains('workshop') || title.contains('school')) {
      return Icons.school;
    }
    return Icons.volunteer_activism;
  }

  Color _activityTint(IconData icon, bool isDark) {
    if (icon == Icons.park) {
      return isDark ? const Color(0xFF50B27C) : const Color(0xFF1C8D55);
    }
    if (icon == Icons.delete_sweep) return _kPrimaryColor;
    if (icon == Icons.school) {
      return isDark ? const Color(0xFF6FA8FF) : const Color(0xFF2B73D6);
    }
    return _kPrimaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.person, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('My Profile', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              if (updated == true && mounted) {
                setState(() {});
              }
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _firebaseService.currentUser == null
            ? Future.value(null)
            : _firebaseService.getMergedUserData(
                _firebaseService.currentUser!.uid,
              ),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentUser = _firebaseService.currentUser;
          final userData = userSnapshot.data ?? <String, dynamic>{};

          final name = _asString(
            userData['name'] ?? currentUser?.displayName,
            fallback: 'Community Volunteer',
          );
          final bio = _asString(
            userData['bio'] ?? userData['about'] ?? userData['description'],
            fallback:
                'Passionate about helping the community, actively participating in volunteer activities, and striving to make a meaningful and lasting positive impact on society.',
          );
          final photoUrl = _asString(
            userData['photoUrl'] ?? userData['avatarUrl'],
          );
          final joinedDate = _asDate(userData['createdAt']);
          return StreamBuilder<Map<String, dynamic>>(
            stream: currentUser == null
                ? Stream.value(const <String, dynamic>{})
                : _firebaseService.streamUserData(currentUser.uid),
            builder: (context, liveUserSnapshot) {
              final liveUserData =
                  liveUserSnapshot.data ?? const <String, dynamic>{};
              final profileData = <String, dynamic>{
                ...userData,
                ...liveUserData,
              };
              final basePoints = _asInt(
                liveUserData['impactPoints'] ??
                    liveUserData['points'] ??
                    liveUserData['rewardPoints'] ??
                    userData['impactPoints'] ??
                    userData['points'] ??
                    userData['rewardPoints'],
                fallback: 0,
              );

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firebaseService.streamOrganizerEvents(),
                builder: (context, eventsSnapshot) {
                  final events =
                      eventsSnapshot.data ?? const <Map<String, dynamic>>[];

                  final attendedEvents = events.where((event) {
                    final awardedIds =
                        (event['awardedParticipantIds'] as List<dynamic>? ??
                                const [])
                            .map((e) => e.toString())
                            .toSet();
                    final uid = currentUser?.uid ?? '';
                    return uid.isNotEmpty && awardedIds.contains(uid);
                  }).toList();

                  final sortedEvents = [...attendedEvents]
                    ..sort((a, b) {
                      final aDate = _asDate(
                        a['eventDate'] ?? a['date'] ?? a['startDate'],
                      );
                      final bDate = _asDate(
                        b['eventDate'] ?? b['date'] ?? b['startDate'],
                      );
                      if (aDate == null && bDate == null) return 0;
                      if (aDate == null) return 1;
                      if (bDate == null) return -1;
                      return bDate.compareTo(aDate);
                    });

                  final eventsAttended = attendedEvents.length;
                  final earnedFromEvents = attendedEvents.fold<int>(0, (
                    runningTotal,
                    event,
                  ) {
                    return runningTotal +
                        _asInt(
                          event['impactPoints'] ??
                              event['points'] ??
                              event['rewardPoints'],
                          fallback: 0,
                        );
                  });
                  final impactPoints = basePoints > 0
                      ? basePoints
                      : earnedFromEvents;

                  return SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  0,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey.shade900.withValues(
                                            alpha: 0.55,
                                          )
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _kPrimaryColor.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Account Actions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        onPressed: _signOut,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _kPrimaryColor,
                                          side: BorderSide(
                                            color: _kPrimaryColor.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.logout,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Sign Out',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 128,
                                            height: 128,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _kPrimaryColor
                                                    .withValues(alpha: 0.25),
                                                width: 4,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: photoUrl.isNotEmpty
                                                  ? Image.network(
                                                      photoUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return _ProfileFallbackAvatar(
                                                              initials:
                                                                  _initials(
                                                                    name,
                                                                  ),
                                                            );
                                                          },
                                                    )
                                                  : _ProfileFallbackAvatar(
                                                      initials: _initials(name),
                                                    ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 4,
                                            bottom: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: _kPrimaryColor,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark
                                                      ? _kBackgroundDark
                                                      : _kBackgroundLight,
                                                  width: 2,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.photo_camera,
                                                size: 14,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        child: Text(
                                          bio,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.calendar_month,
                                            size: 16,
                                            color: _kPrimaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatJoinedDate(joinedDate),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _kPrimaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (currentUser != null) ...[
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _openCreatePostScreen(
                                            profileData,
                                            isDark,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF1E7E34,
                                              ).withValues(alpha: 0.18),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              size: 22,
                                              color: Color(0xFF1E7E34),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  16,
                                  4,
                                ),
                                child: Text(
                                  'IMPACT OVERVIEW',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  6,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _ProfileStatCard(
                                        title: 'Impact Points',
                                        value: impactPoints.toString(),
                                        valueColor: _kPrimaryColor,
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ProfileStatCard(
                                        title: 'Events Attended',
                                        value: eventsAttended.toString(),
                                        valueColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'MY POSTS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (currentUser != null)
                                      IconButton(
                                        onPressed: () => _openCreatePostScreen(
                                          profileData,
                                          isDark,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        style: IconButton.styleFrom(
                                          backgroundColor: _kPrimaryColor
                                              .withValues(alpha: 0.14),
                                          foregroundColor: _kPrimaryColor,
                                        ),
                                        icon: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (currentUser != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    8,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade900
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      'Use the add-post icon to create a post.',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'ACTIVITY HISTORY',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Text(
                                      'View All',
                                      style: TextStyle(
                                        color: _kPrimaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  0,
                                ),
                                child: sortedEvents.isEmpty
                                    ? Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey.shade900
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          'No verified activity yet. Your history and points update after organizer marks attendance.',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          for (final event in sortedEvents.take(
                                            6,
                                          ))
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: _ProfileActivityCard(
                                                icon: _activityIcon(event),
                                                iconColor: _activityTint(
                                                  _activityIcon(event),
                                                  isDark,
                                                ),
                                                title: _asString(
                                                  event['title'] ??
                                                      event['eventName'] ??
                                                      event['name'],
                                                  fallback:
                                                      'Community Activity',
                                                ),
                                                subtitle:
                                                    '${_relativeDate(_asDate(event['eventDate'] ?? event['date'] ?? event['startDate']))} • ${_asString(event['location'] ?? event['venue'], fallback: 'Community')}',
                                                points: _asInt(
                                                  event['impactPoints'] ??
                                                      event['points'] ??
                                                      event['rewardPoints'],
                                                  fallback: 0,
                                                ),
                                                isDark: isDark,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DiscoverEventsScreen()),
            );
            return;
          }
          if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MyEventsScreen()),
            );
            return;
          }
          if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CommunityScreen()),
            );
            return;
          }

          if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MyFriendsScreen()),
            );
            return;
          }

          if (index == 4) {
            return;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kPrimaryColor,
        unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[700],
        backgroundColor: isDark ? _kBackgroundDark : Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Events'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'My Events',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'My Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _CreatePostScreen extends StatefulWidget {
  const _CreatePostScreen({
    required this.profileData,
    required this.isDark,
    required this.firebaseService,
    required this.imagePicker,
  });

  final Map<String, dynamic> profileData;
  final bool isDark;
  final FirebaseService firebaseService;
  final ImagePicker imagePicker;

  @override
  State<_CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<_CreatePostScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await widget.imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;
    final imageBytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _selectedImageBytes = imageBytes;
    });
  }

  Future<void> _submitPost() async {
    final currentUser = widget.firebaseService.currentUser;
    if (currentUser == null) return;

    final description = _descriptionController.text.trim();
    final rootMessenger = ScaffoldMessenger.of(context);
    String? uploadedImageUrl;

    if (_selectedImage == null) {
      rootMessenger.showSnackBar(
        const SnackBar(content: Text('Please select an image.')),
      );
      return;
    }
    if (description.isEmpty) {
      rootMessenger.showSnackBar(
        const SnackBar(content: Text('Add a description first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      uploadedImageUrl = await _uploadPostImage(
        _selectedImage!,
        currentUser.uid,
      );
      final userName = _asString(
        widget.profileData['name'] ?? currentUser.displayName,
        fallback: 'Community Volunteer',
      );
      final userBio = _asString(
        widget.profileData['bio'] ??
            widget.profileData['about'] ??
            widget.profileData['description'],
      );
      final userPhotoUrl = _asString(
        widget.profileData['photoUrl'] ?? widget.profileData['avatarUrl'],
      );

      final postsRef = FirebaseFirestore.instance.collection('posts').doc();
      await postsRef.set({
        'postId': postsRef.id,
        'authorUid': currentUser.uid,
        'authorName': userName,
        'authorBio': userBio,
        'authorPhotoUrl': userPhotoUrl,
        'description': description,
        'imageUrl': uploadedImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isSaving = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Post Created'),
            content: const Text('Your post has been created.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (uploadedImageUrl != null && uploadedImageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(uploadedImageUrl).delete();
        } catch (_) {
          // Ignore cleanup failures and surface the original error.
        }
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      rootMessenger.showSnackBar(
        SnackBar(content: Text('Failed to create post: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _isSaving ? null : _pickImage,
                child: Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to choose image',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Write a description...',
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFallbackAvatar extends StatelessWidget {
  const _ProfileFallbackAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2B2B), Color(0xFF4C4C4C)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.isDark,
  });

  final String title;
  final String value;
  final Color valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActivityCard extends StatelessWidget {
  const _ProfileActivityCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int points;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$points points',
            style: TextStyle(
              color: isDark ? const Color(0xFF59D99D) : const Color(0xFF1C8D55),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
