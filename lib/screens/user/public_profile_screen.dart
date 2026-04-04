import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'discover_events_screen.dart';
import 'my_events_screen.dart';
import 'myfriends_screen.dart';
import 'user_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _query = '';
  String _roleFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatPoints(int points) {
    if (points >= 1000000) {
      return '${(points / 1000000).toStringAsFixed(1)}M';
    }
    if (points >= 1000) {
      return '${(points / 1000).toStringAsFixed(1)}K';
    }
    return points.toString();
  }

  String _standingText(int rank, int total) {
    if (total == 0) return 'New Contributor';
    final percentile = ((rank / total) * 100).clamp(1, 100).round();
    final top = percentile <= 5
        ? 'Top 5%'
        : percentile <= 10
        ? 'Top 10%'
        : percentile <= 25
        ? 'Top 25%'
        : 'Top 50%';
    return '$top Contributor';
  }

  List<Map<String, dynamic>> _filteredUsers(List<Map<String, dynamic>> users) {
    final q = _query.trim().toLowerCase();
    final filtered = users.where((user) {
      final role = _asString(user['role']).toLowerCase();
      if (_roleFilter != 'All' && role != _roleFilter.toLowerCase()) {
        return false;
      }

      if (q.isEmpty) return true;
      final name = _asString(
        user['name'] ?? user['displayName'] ?? user['fullName'],
      ).toLowerCase();
      return name.contains(q);
    }).toList();

    filtered.sort(
      (a, b) => _asInt(
        b['impactPoints'] ?? b['points'],
      ).compareTo(_asInt(a['impactPoints'] ?? a['points'])),
    );
    return filtered;
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
            Icon(Icons.groups, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text(
              'Community Impact',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load contributors right now.',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final users = (snapshot.data?.docs ?? const [])
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          final contributors = _filteredUsers(users);

          final currentRank = contributors.isEmpty ? 0 : 1;
          final standing = _standingText(currentRank, contributors.length);

          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0x660DF233), Color(0x330DF233)],
                          ),
                          border: Border.all(
                            color: _kPrimaryColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Standing',
                                    style: TextStyle(
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.grey[200]
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    standing,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Keep it up, you are making a difference!',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _kPrimaryColor,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kPrimaryColor.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.military_tech,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _query = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _kPrimaryColor),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Top Contributors',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                builder: (context) {
                                  final options = [
                                    'All',
                                    'Volunteer',
                                    'Organizer',
                                  ];
                                  return SafeArea(
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        for (final option in options)
                                          ListTile(
                                            title: Text(option),
                                            trailing: _roleFilter == option
                                                ? const Icon(
                                                    Icons.check,
                                                    color: _kPrimaryColor,
                                                  )
                                                : null,
                                            onTap: () {
                                              setState(() {
                                                _roleFilter = option;
                                              });
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.tune),
                            label: const Text('Filter'),
                            style: TextButton.styleFrom(
                              foregroundColor: _kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: contributors.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No contributors match your search.',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: contributors.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final user = contributors[index];
                                final name = _asString(
                                  user['name'] ??
                                      user['displayName'] ??
                                      user['fullName'],
                                  fallback: 'Unnamed User',
                                );
                                final points = _asInt(
                                  user['impactPoints'] ??
                                      user['points'] ??
                                      user['rewardPoints'],
                                  fallback: 0,
                                );
                                final photoUrl = _asString(
                                  user['photoUrl'] ?? user['avatarUrl'],
                                );
                                final isVerified =
                                    _asString(user['verified']).toLowerCase() ==
                                        'true' ||
                                    user['verified'] == true;

                                return Container(
                                  padding: const EdgeInsets.all(12),
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.18 : 0.04,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _kPrimaryColor.withValues(
                                              alpha: 0.2,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: photoUrl.isNotEmpty
                                              ? Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, error, stackTrace) {
                                                        return _FallbackAvatar(
                                                          initials: _initials(
                                                            name,
                                                          ),
                                                        );
                                                      },
                                                )
                                              : _FallbackAvatar(
                                                  initials: _initials(name),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isVerified)
                                                  const Icon(
                                                    Icons.verified,
                                                    size: 16,
                                                    color: _kPrimaryColor,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.volunteer_activism,
                                                  size: 14,
                                                  color: _kPrimaryColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Impact Points: ${_formatPoints(points)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.grey.shade300
                                                        : Colors.grey.shade700,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.tonal(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PublicUserDetailScreen(
                                                    userData: user,
                                                  ),
                                            ),
                                          );
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade100,
                                          foregroundColor: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'View Profile',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
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

          if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MyFriendsScreen()),
            );
            return;
          }

          if (index == 4) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const UserProfileScreen()),
            );
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

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.initials});

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
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class PublicUserDetailScreen extends StatefulWidget {
  const PublicUserDetailScreen({super.key, required this.userData});

  final Map<String, dynamic> userData;

  @override
  State<PublicUserDetailScreen> createState() => _PublicUserDetailScreenState();
}

class _PublicUserDetailScreenState extends State<PublicUserDetailScreen> {
  List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((entry) => entry.toString()).toList();
  }

  Future<void> _toggleFollow(String targetUserId, bool isFollowing) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to follow users.')),
      );
      return;
    }

    if (targetUserId.isEmpty || targetUserId == currentUser.uid) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid);

    try {
      await userRef.set({
        'followingUserIds': isFollowing
            ? FieldValue.arrayRemove([targetUserId])
            : FieldValue.arrayUnion([targetUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update follow status.')),
      );
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  DateTime? _asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic date = value?.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
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
    return '';
  }

  IconData _activityIcon(Map<String, dynamic> event) {
    final text = _asString(
      event['title'] ??
          event['eventName'] ??
          event['name'] ??
          event['category'],
    ).toLowerCase();

    if (text.contains('marathon') || text.contains('run')) {
      return Icons.directions_run;
    }
    if (text.contains('plant') || text.contains('garden')) {
      return Icons.local_florist;
    }
    if (text.contains('recycl') || text.contains('cleanup')) {
      return Icons.recycling;
    }
    if (text.contains('food') || text.contains('charity')) {
      return Icons.volunteer_activism;
    }
    return Icons.event;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String uid = _asString(
      widget.userData['id'] ?? widget.userData['uid'],
    );
    final String name = _asString(
      widget.userData['name'] ??
          widget.userData['displayName'] ??
          widget.userData['fullName'],
      fallback: 'Community Member',
    );
    final String photoUrl = _asString(
      widget.userData['photoUrl'] ?? widget.userData['avatarUrl'],
    );
    final String bio = _asString(
      widget.userData['bio'] ??
          widget.userData['about'] ??
          widget.userData['description'],
      fallback:
          'Passionate about environmental conservation and community building.',
    );
    final int baseImpactPoints = _asInt(
      widget.userData['impactPoints'] ??
          widget.userData['points'] ??
          widget.userData['rewardPoints'],
      fallback: 0,
    );

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
            Text('User Profile', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: uid.isEmpty
            ? const Stream.empty()
            : FirebaseFirestore.instance
                  .collection('events')
                  .where('participantIds', arrayContains: uid)
                  .snapshots(),
        builder: (context, snapshot) {
          final allEvents = (snapshot.data?.docs ?? const [])
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

          // Only include events where the user is in awardedParticipantIds
          final activityEvents = allEvents.where((event) {
            final awarded = event['awardedParticipantIds'];
            if (awarded is List) {
              return awarded.contains(uid);
            }
            return false;
          }).toList();

          activityEvents.sort((a, b) {
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

          final attendanceCount = activityEvents.length;
          final earnedFromEvents = activityEvents.fold<int>(0, (
            runningTotal,
            event,
          ) {
            return runningTotal +
                _asInt(event['impactPoints'] ?? event['points']);
          });
          final totalImpact = baseImpactPoints > 0
              ? baseImpactPoints
              : earnedFromEvents;

          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                        child: Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 132,
                                    height: 132,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _kPrimaryColor,
                                        width: 4,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: photoUrl.isNotEmpty
                                          ? Image.network(
                                              photoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, error, stackTrace) {
                                                    return _FallbackAvatar(
                                                      initials: _initials(name),
                                                    );
                                                  },
                                            )
                                          : _FallbackAvatar(
                                              initials: _initials(name),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: Container(
                                      width: 24,
                                      height: 24,
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
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                bio,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (uid.isNotEmpty &&
                                  uid != FirebaseAuth.instance.currentUser?.uid)
                                StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>
                                >(
                                  stream:
                                      FirebaseAuth.instance.currentUser == null
                                      ? const Stream.empty()
                                      : FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .uid,
                                            )
                                            .snapshots(),
                                  builder: (context, followSnapshot) {
                                    final followingIds = _asStringList(
                                      followSnapshot.data
                                          ?.data()?['followingUserIds'],
                                    );
                                    final isFollowing = followingIds.contains(
                                      uid,
                                    );

                                    return Center(
                                      child: SizedBox(
                                        width: 160,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _toggleFollow(uid, isFollowing),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isFollowing
                                                ? const Color(0xFF1E7E34)
                                                : _kPrimaryColor,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Text(
                                            isFollowing
                                                ? 'Following'
                                                : 'Follow',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ImpactCard(
                                title: 'Total Impact',
                                value: totalImpact.toString(),
                                caption: 'Points Earned',
                                isDark: isDark,
                                valueColor: _kPrimaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ImpactCard(
                                title: 'Attendance',
                                value: attendanceCount.toString(),
                                caption: 'Events Attended',
                                isDark: isDark,
                                valueColor: isDark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              'Activity History',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _kPrimaryColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Recent',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kPrimaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (activityEvents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Text(
                              'No activity yet for this user.',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            children: [
                              for (final event in activityEvents.take(8))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ActivityCard(
                                    eventId: _asString(event['id']),
                                    title: _asString(
                                      event['title'] ??
                                          event['eventName'] ??
                                          event['name'],
                                      fallback: 'Community Activity',
                                    ),
                                    dateLabel: _relativeDate(
                                      _asDate(
                                        event['eventDate'] ??
                                            event['date'] ??
                                            event['startDate'],
                                      ),
                                    ),
                                    icon: _activityIcon(event),
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DiscoverEventsScreen()),
              (route) => false,
            );
            return;
          }

          if (index == 1) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MyEventsScreen()),
              (route) => false,
            );
            return;
          }

          if (index == 3) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MyFriendsScreen()),
              (route) => false,
            );
            return;
          }

          if (index == 4) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              (route) => false,
            );
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

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.isDark,
    required this.valueColor,
  });

  final String title;
  final String value;
  final String caption;
  final bool isDark;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.55)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.eventId,
    required this.title,
    required this.dateLabel,
    required this.icon,
    required this.points,
    required this.isDark,
  });

  final String eventId;
  final String title;
  final String dateLabel;
  final IconData icon;
  final int points;
  final bool isDark;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Future<void> _toggleLike(
    BuildContext context,
    String currentUid,
    bool hasLiked,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like activities.')),
      );
      return;
    }
    if (eventId.isEmpty) return;

    final likeDocRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('likes')
        .doc(currentUid);

    try {
      if (hasLiked) {
        await likeDocRef.delete();
      } else {
        await likeDocRef.set({
          'uid': currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update like right now.')),
      );
    }
  }

  Future<List<Map<String, String>>> _loadLikedByUsers(
    List<String> likedByUids,
  ) async {
    if (likedByUids.isEmpty) return const [];

    final users = <Map<String, String>>[];
    for (var i = 0; i < likedByUids.length; i += 10) {
      final end = (i + 10 < likedByUids.length) ? i + 10 : likedByUids.length;
      final batchIds = likedByUids.sublist(i, end);

      final batchSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();

      for (final doc in batchSnapshot.docs) {
        final data = doc.data();
        final name = (data['name'] ?? data['displayName'] ?? data['fullName'])
            ?.toString()
            .trim();
        final photoUrl = (data['photoUrl'] ?? data['avatarUrl'])
            ?.toString()
            .trim();
        users.add({
          'uid': doc.id,
          'name': (name == null || name.isEmpty) ? 'Community Member' : name,
          'photoUrl': photoUrl ?? '',
        });
      }
    }

    final byUid = {for (final user in users) user['uid']!: user};
    final ordered = <Map<String, String>>[];
    for (final uid in likedByUids) {
      ordered.add(
        byUid[uid] ?? {'uid': uid, 'name': 'Community Member', 'photoUrl': ''},
      );
    }

    return ordered;
  }

  void _showLikedBySheet(BuildContext context, List<String> likedByUids) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liked by',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                if (likedByUids.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No likes yet for this activity.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  FutureBuilder<List<Map<String, String>>>(
                    future: _loadLikedByUsers(likedByUids),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final users = snapshot.data ?? const [];
                      if (users.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'No likes yet for this activity.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }

                      return Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: users.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final name = user['name'] ?? 'Community Member';
                            final photoUrl = user['photoUrl'] ?? '';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: _kPrimaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl.isEmpty
                                    ? Text(
                                        _initials(name),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final likesStream = eventId.isEmpty
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('likes')
              .snapshots();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.45)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _kPrimaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: likesStream,
              builder: (context, likesSnapshot) {
                final likedByUids = (likesSnapshot.data?.docs ?? const [])
                    .map((doc) => doc.id)
                    .toList();
                final likesCount = likedByUids.length;
                final hasLiked =
                    currentUid != null && likedByUids.contains(currentUid);

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () =>
                                _showLikedBySheet(context, likedByUids),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                likesCount == 0
                                    ? 'Be the first to like'
                                    : '$likesCount ${likesCount == 1 ? 'Like' : 'Likes'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          onPressed: currentUid == null
                              ? () => _toggleLike(context, '', false)
                              : () =>
                                    _toggleLike(context, currentUid, hasLiked),
                          icon: Icon(
                            hasLiked ? Icons.favorite : Icons.favorite_border,
                            color: hasLiked
                                ? const Color(0xFFFF3B5C)
                                : (isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700),
                          ),
                        ),
                        Text(
                          '+$points Points',
                          style: const TextStyle(
                            color: _kPrimaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
