import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'community_screen.dart';
import 'discover_events_screen.dart';
import 'my_events_screen.dart';
import '../../widgets/social_post_card.dart' as social_post_card;
import 'public_profile_screen.dart';
import 'user_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class MyFriendsScreen extends StatefulWidget {
  const MyFriendsScreen({super.key});

  @override
  State<MyFriendsScreen> createState() => _MyFriendsScreenState();
}

class _MyFriendsScreenState extends State<MyFriendsScreen> {
  bool _showFriendsPosts = true;

  Future<void> _unfollowUser(String targetUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || targetUserId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
            'followingUserIds': FieldValue.arrayRemove([targetUserId]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to unfollow right now.')),
      );
    }
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((entry) => entry.toString()).toList();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Future<List<Map<String, dynamic>>> _loadFriends(List<String> userIds) async {
    if (userIds.isEmpty) return const [];

    final friends = <Map<String, dynamic>>[];
    for (var index = 0; index < userIds.length; index += 10) {
      final end = (index + 10 < userIds.length) ? index + 10 : userIds.length;
      final batch = userIds.sublist(index, end);
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        friends.add({'id': doc.id, ...doc.data()});
      }
    }

    final byId = {for (final friend in friends) friend['id'] as String: friend};
    return [
      for (final id in userIds)
        byId[id] ?? {'id': id, 'name': 'Community Member'},
    ];
  }

  Future<void> _openFollowingScreen(
    BuildContext context,
    List<Map<String, dynamic>> friends,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FollowingListScreen(
          initialFriends: friends,
          unfollowUser: _unfollowUser,
          asString: _asString,
          initials: _initials,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('My Friends', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: currentUser == null
            ? Center(
                child: Text(
                  'Please sign in to view your friends.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load your friends right now.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),
                    );
                  }

                  final followingIds = _asStringList(
                    snapshot.data?.data()?['followingUserIds'],
                  );

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadFriends(followingIds),
                    builder: (context, friendsSnapshot) {
                      if (friendsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final friends = friendsSnapshot.data ?? const [];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          Colors.grey.shade900,
                                          const Color(0xFF2A231F),
                                        ]
                                      : [Colors.white, const Color(0xFFF1F8EF)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _kPrimaryColor.withValues(alpha: 0.22),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.2 : 0.06,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'My Friends',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        onPressed: () => _openFollowingScreen(
                                          context,
                                          friends,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _kPrimaryColor,
                                          side: BorderSide(
                                            color: _kPrimaryColor.withValues(
                                              alpha: 0.55,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.group_outlined,
                                          size: 17,
                                        ),
                                        label: Text(
                                          'Following (${friends.length})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    friends.isEmpty
                                        ? 'You are not following anyone yet.'
                                        : 'View your following list.',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _showFriendsPosts = true;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _showFriendsPosts
                                          ? _kPrimaryColor
                                          : (isDark
                                                ? Colors.grey.shade800
                                                : Colors.white),
                                      foregroundColor: _showFriendsPosts
                                          ? Colors.black
                                          : (isDark
                                                ? Colors.white
                                                : Colors.black),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: _showFriendsPosts ? 0 : 1,
                                      side: BorderSide(
                                        color: _kPrimaryColor.withValues(
                                          alpha: _showFriendsPosts ? 0 : 0.22,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text(
                                      'Friends Posts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _showFriendsPosts = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: !_showFriendsPosts
                                          ? _kPrimaryColor
                                          : (isDark
                                                ? Colors.grey.shade800
                                                : Colors.white),
                                      foregroundColor: !_showFriendsPosts
                                          ? Colors.black
                                          : (isDark
                                                ? Colors.white
                                                : Colors.black),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: !_showFriendsPosts ? 0 : 1,
                                      side: BorderSide(
                                        color: _kPrimaryColor.withValues(
                                          alpha: !_showFriendsPosts ? 0 : 0.22,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text(
                                      'My Posts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('posts')
                                  .orderBy('createdAt', descending: true)
                                  .limit(40)
                                  .snapshots(),
                              builder: (context, postsSnapshot) {
                                if (postsSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final posts =
                                    (postsSnapshot.data?.docs ?? const [])
                                        .where((doc) {
                                          final authorUid = _asString(
                                            doc.data()['authorUid'],
                                          );
                                          if (!_showFriendsPosts) {
                                            return authorUid == currentUser.uid;
                                          }
                                          return followingIds.contains(
                                            authorUid,
                                          );
                                        })
                                        .toList();

                                if (posts.isEmpty) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade900
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.14 : 0.05,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _showFriendsPosts
                                          ? 'No posts from the people you follow yet.'
                                          : 'You have not created any posts yet.',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children: [
                                    for (final post in posts.take(10))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: social_post_card.SocialPostCard(
                                          postId: post.id,
                                          postData: post.data(),
                                          isDark: isDark,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
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

class _FollowingListScreen extends StatefulWidget {
  const _FollowingListScreen({
    required this.initialFriends,
    required this.unfollowUser,
    required this.asString,
    required this.initials,
  });

  final List<Map<String, dynamic>> initialFriends;
  final Future<void> Function(String) unfollowUser;
  final String Function(dynamic, {String fallback}) asString;
  final String Function(String) initials;

  @override
  State<_FollowingListScreen> createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends State<_FollowingListScreen> {
  late final List<Map<String, dynamic>> _friends;

  @override
  void initState() {
    super.initState();
    _friends = List<Map<String, dynamic>>.from(widget.initialFriends);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
      appBar: AppBar(
        title: const Text(
          'Following List',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: _friends.isEmpty
            ? Center(
                child: Text(
                  'You are not following anyone yet.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                itemCount: _friends.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  final friendName = widget.asString(
                    friend['name'] ??
                        friend['displayName'] ??
                        friend['fullName'],
                    fallback: 'Community Member',
                  );
                  final friendPhoto = widget.asString(
                    friend['photoUrl'] ?? friend['avatarUrl'],
                  );
                  final friendId = widget.asString(
                    friend['id'] ?? friend['uid'],
                  );

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [Colors.grey.shade900, const Color(0xFF2A231F)]
                            : [Colors.white, const Color(0xFFF4FAF2)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PublicUserDetailScreen(userData: friend),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: _kPrimaryColor.withValues(
                              alpha: 0.2,
                            ),
                            backgroundImage: friendPhoto.isNotEmpty
                                ? NetworkImage(friendPhoto)
                                : null,
                            child: friendPhoto.isEmpty
                                ? Text(
                                    widget.initials(friendName),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            friendName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: friendId.isEmpty
                              ? null
                              : () async {
                                  await widget.unfollowUser(friendId);
                                  if (!context.mounted) return;
                                  setState(() {
                                    _friends.removeWhere(
                                      (entry) =>
                                          widget.asString(
                                            entry['id'] ?? entry['uid'],
                                          ) ==
                                          friendId,
                                    );
                                  });
                                },
                          child: const Text('Unfollow'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
