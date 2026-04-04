import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'discover_events_screen.dart';
import 'my_events_screen.dart';
import 'myfriends_screen.dart';
import 'public_profile_screen.dart';
import 'user_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _query = '';
  String _pointsFilter = 'All';

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

  bool _isActiveUser(Map<String, dynamic> user) {
    final deletionFlag =
        user['isDeleted'] == true ||
        _asString(user['isDeleted']).toLowerCase() == 'true';
    final status = _asString(
      user['accountStatus'] ?? user['status'],
    ).toLowerCase();
    final statusDeleted =
        status == 'deleted' || status == 'inactive' || status == 'disabled';

    final hasEmail = _asString(user['email']).isNotEmpty;
    final hasId = _asString(
      user['authUid'] ?? user['uid'] ?? user['userId'] ?? user['id'],
    ).isNotEmpty;

    return !deletionFlag && !statusDeleted && hasEmail && hasId;
  }

  List<Map<String, dynamic>> _filteredUsers(List<Map<String, dynamic>> users) {
    final q = _query.trim().toLowerCase();
    final filtered = users.where((user) {
      // Show only Volunteers
      final role = _asString(user['role']).toLowerCase();
      if (role != 'volunteer') {
        return false;
      }

      final points = _asInt(
        user['impactPoints'] ?? user['points'] ?? user['rewardPoints'],
      );
      switch (_pointsFilter) {
        case 'High':
          if (points < 500) return false;
          break;
        case 'Medium':
          if (points < 100 || points >= 500) return false;
          break;
        case 'Low':
          if (points >= 100) return false;
          break;
        default:
          break;
      }

      if (q.isEmpty) return true;
      final name = _asString(
        user['name'] ?? user['displayName'] ?? user['fullName'],
      ).toLowerCase();
      return name.contains(q);
    }).toList();

    filtered.sort(
      (a, b) => _asInt(b['impactPoints'] ?? b['points'] ?? b['rewardPoints'])
          .compareTo(
            _asInt(a['impactPoints'] ?? a['points'] ?? a['rewardPoints']),
          ),
    );

    return filtered;
  }

  String _standingText(int rank, int total) {
    if (total == 0) return 'New Volunteer';
    final percentile = ((rank / total) * 100).clamp(1, 100).round();
    if (percentile <= 5) return 'Top 5% Contributor';
    if (percentile <= 10) return 'Top 10% Contributor';
    if (percentile <= 25) return 'Top 25% Contributor';
    return 'Top 50% Volunteer';
  }

  Widget _avatar(String photoUrl, String name, bool isDark) {
    if (photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) {
            return _FallbackAvatar(initials: _initials(name), isDark: isDark);
          },
        ),
      );
    }
    return _FallbackAvatar(initials: _initials(name), isDark: isDark);
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
              .where(_isActiveUser)
              .toList();
          final contributors = _filteredUsers(users);

          final standing = _standingText(
            contributors.isEmpty ? 0 : 1,
            contributors.length,
          );

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
                          color: _kPrimaryColor.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Standing',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _kPrimaryColor,
                                      letterSpacing: 1,
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
                                    "Keep it up, you're making a difference!",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
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
                                      alpha: 0.3,
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
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                            borderSide: BorderSide(color: _kPrimaryColor),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Top Volunteers',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                builder: (sheetContext) {
                                  return SafeArea(
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            12,
                                            16,
                                            12,
                                          ),
                                          child: Text(
                                            'Points',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.grey.shade300
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        for (final option in [
                                          'All',
                                          'High (500+)',
                                          'Medium (100-499)',
                                          'Low (0-99)',
                                        ])
                                          ListTile(
                                            title: Text(option),
                                            trailing:
                                                _pointsFilter ==
                                                    option.split(' ')[0]
                                                ? const Icon(
                                                    Icons.check,
                                                    color: _kPrimaryColor,
                                                  )
                                                : null,
                                            onTap: () {
                                              setState(() {
                                                if (option == 'All') {
                                                  _pointsFilter = 'All';
                                                } else if (option.startsWith(
                                                  'High',
                                                )) {
                                                  _pointsFilter = 'High';
                                                } else if (option.startsWith(
                                                  'Medium',
                                                )) {
                                                  _pointsFilter = 'Medium';
                                                } else {
                                                  _pointsFilter = 'Low';
                                                }
                                              });
                                              Navigator.of(sheetContext).pop();
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            child: const Text(
                              'Filter',
                              style: TextStyle(
                                color: _kPrimaryColor,
                                fontWeight: FontWeight.w700,
                              ),
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
                                    user['verified'] == true ||
                                    _asString(user['verified']).toLowerCase() ==
                                        'true';

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
                                        child: _avatar(photoUrl, name, isDark),
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
                                                  'Impact Points: $points',
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
  const _FallbackAvatar({required this.initials, required this.isDark});

  final String initials;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1F1F1F), Color(0xFF424242)]
              : const [Color(0xFF747474), Color(0xFF9A9A9A)],
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
