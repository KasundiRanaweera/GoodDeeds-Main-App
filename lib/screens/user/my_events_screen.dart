import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import 'discover_events_screen.dart';
import 'community_screen.dart';
import 'event_details_screen.dart';
import 'myfriends_screen.dart';
import 'user_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);
const _kStatusJoined = 'Joined';
const _kStatusPending = 'Pending';
const _kStatusCompleted = 'Completed';
const _kStatusMissed = 'Missed';
const _kPendingInfoText =
    'Attendance pending - awaiting organizer confirmation.';
const _kMissedInfoText = 'Not attended. No points awarded.';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<String> _tabs = const ['All', 'Upcoming', 'Past'];
  int _selectedTab = 0;
  final Set<String> _leavingEventIds = <String>{};
  final Set<String> _hiddenEventIds = <String>{};

  Future<bool> _confirmLeaveEvent(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: const Text('Are you sure you want to unjoin this event?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _leaveEvent(BuildContext context, String eventId) async {
    if (eventId.isEmpty || _leavingEventIds.contains(eventId)) return;

    setState(() => _leavingEventIds.add(eventId));
    try {
      await _firebaseService.leaveEvent(eventId: eventId);
      if (!context.mounted) return;
      setState(() => _hiddenEventIds.add(eventId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event removed from My Events.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update event: $e')));
    } finally {
      if (mounted) {
        setState(() => _leavingEventIds.remove(eventId));
      }
    }
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
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

  DateTime? _eventDate(Map<String, dynamic> event) {
    return _asDate(event['eventDate'] ?? event['date'] ?? event['startDate']);
  }

  Set<String> _asStringSet(dynamic value) {
    if (value is Iterable) {
      return value.map((e) => e.toString()).toSet();
    }
    return <String>{};
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Date to be announced';

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

    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, ${date.year} • $hour12:$minute $suffix';
  }

  List<Map<String, dynamic>> _filteredEvents(
    List<Map<String, dynamic>> events,
  ) {
    List<Map<String, dynamic>> filtered;
    if (_selectedTab == 0) {
      filtered = List<Map<String, dynamic>>.from(events);
    } else {
      final now = DateTime.now();
      final isUpcomingTab = _selectedTab == 1;

      filtered = events.where((event) {
        final date = _eventDate(event);
        if (date == null) return isUpcomingTab;
        final isPast = date.isBefore(now);
        return isUpcomingTab ? !isPast : isPast;
      }).toList();
    }

    filtered.sort((a, b) {
      final aAddedAt = _asDate(
        a['createdAt'] ?? a['joinedAt'] ?? a['updatedAt'] ?? a['eventDate'],
      );
      final bAddedAt = _asDate(
        b['createdAt'] ?? b['joinedAt'] ?? b['updatedAt'] ?? b['eventDate'],
      );
      if (aAddedAt == null && bAddedAt == null) return 0;
      if (aAddedAt == null) return 1;
      if (bAddedAt == null) return -1;
      return bAddedAt.compareTo(aAddedAt);
    });

    return filtered;
  }

  String _statusForEvent(Map<String, dynamic> event, String uid) {
    final date = _eventDate(event);
    if (date == null) return _kStatusJoined;

    final now = DateTime.now();
    if (date.isAfter(now)) return _kStatusJoined;

    final checkedInIds = _asStringSet(event['checkedInIds']);
    final awardedIds = _asStringSet(event['awardedParticipantIds']);

    if (awardedIds.contains(uid) || checkedInIds.contains(uid)) {
      return _kStatusCompleted;
    }

    final pendingUntil = date.add(const Duration(days: 2));
    if (!now.isAfter(pendingUntil)) {
      return _kStatusPending;
    }

    return _kStatusMissed;
  }

  Color _statusBackground(String status, bool isDark) {
    switch (status) {
      case _kStatusJoined:
        return _kPrimaryColor.withValues(alpha: 0.15);
      case _kStatusPending:
        return (isDark ? Colors.amber.shade700 : Colors.amber.shade100)
            .withValues(alpha: isDark ? 0.35 : 1);
      case _kStatusCompleted:
        return _kPrimaryColor.withValues(alpha: isDark ? 0.12 : 0.2);
      case _kStatusMissed:
        return (isDark ? Colors.orange.shade700 : Colors.orange.shade100)
            .withValues(alpha: isDark ? 0.4 : 1);
      default:
        return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status, bool isDark) {
    switch (status) {
      case _kStatusJoined:
        return _kPrimaryColor;
      case _kStatusPending:
        return isDark ? Colors.amber.shade100 : Colors.amber.shade900;
      case _kStatusCompleted:
        return isDark ? _kPrimaryColor : Colors.black87;
      case _kStatusMissed:
        return isDark ? Colors.orange.shade200 : Colors.orange.shade900;
      default:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? _kBackgroundDark : _kBackgroundLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.event, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('My Events', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: const [],
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? _kBackgroundDark : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = i),
                      child: Container(
                        padding: const EdgeInsets.only(top: 14, bottom: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedTab == i
                                  ? _kPrimaryColor
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == i
                                ? _kPrimaryColor
                                : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firebaseService.streamMyJoinedEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load your events right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                }

                final allEvents = snapshot.data ?? const [];
                final events = _filteredEvents(allEvents).where((event) {
                  final id = _asString(event['id'] ?? event['eventId']);
                  return !_hiddenEventIds.contains(id);
                }).toList();
                final currentUid = _firebaseService.currentUser?.uid ?? '';

                if (events.isEmpty) {
                  final emptyText = _selectedTab == 0
                      ? 'You have not joined any events yet.'
                      : _selectedTab == 1
                      ? 'No upcoming joined events.'
                      : 'No completed events yet.';

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        emptyText,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  itemCount: events.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final eventId = _asString(event['id'] ?? event['eventId']);
                    final title = _asString(
                      event['title'] ?? event['eventName'] ?? event['name'],
                      fallback: 'Untitled Event',
                    );
                    final date = _eventDate(event);
                    final location = _asString(
                      event['location'] ?? event['venue'] ?? event['address'],
                      fallback: 'Location to be announced',
                    );
                    final imageUrl = _asString(
                      event['imageUrl'] ??
                          event['bannerUrl'] ??
                          event['photoUrl'],
                    );
                    final status = _statusForEvent(event, currentUid);
                    final isLeaving = _leavingEventIds.contains(eventId);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EventDetailsScreen(eventData: event),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.12 : 0.05,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, error, stackTrace) =>
                                                  Container(
                                                    color: isDark
                                                        ? Colors.grey.shade800
                                                        : Colors.grey.shade200,
                                                    child: const Icon(
                                                      Icons.image,
                                                    ),
                                                  ),
                                        )
                                      : Container(
                                          color: isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade200,
                                          child: const Icon(Icons.image),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusBackground(
                                              status,
                                              isDark,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: _statusTextColor(
                                                status,
                                                isDark,
                                              ),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatDateTime(date),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: isDark
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            location,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (status == _kStatusPending) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.hourglass_top,
                                            size: 14,
                                            color: isDark
                                                ? Colors.amber.shade100
                                                : Colors.amber.shade900,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _kPendingInfoText,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.amber.shade100
                                                    : Colors.amber.shade900,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (status == _kStatusMissed) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: isDark
                                                ? Colors.orange.shade200
                                                : Colors.orange.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _kMissedInfoText,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.orange.shade200
                                                    : Colors.orange.shade800,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (status == _kStatusJoined) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton(
                                          onPressed: isLeaving
                                              ? null
                                              : () async {
                                                  if (date != null &&
                                                      !date.isAfter(
                                                        DateTime.now(),
                                                      )) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          "You can't leave now.",
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  final shouldLeave =
                                                      await _confirmLeaveEvent(
                                                        context,
                                                      );
                                                  if (!context.mounted) return;
                                                  if (!shouldLeave) return;
                                                  await _leaveEvent(
                                                    context,
                                                    eventId,
                                                  );
                                                },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark
                                                ? Colors.grey.shade200
                                                : Colors.grey.shade700,
                                            side: BorderSide(
                                              color: isDark
                                                  ? Colors.grey.shade700
                                                  : Colors.grey.shade400,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          child: Text(
                                            isLeaving ? 'Updating...' : 'Leave',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DiscoverEventsScreen()),
            );
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CommunityScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MyFriendsScreen()),
            );
          } else if (index == 4) {
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
