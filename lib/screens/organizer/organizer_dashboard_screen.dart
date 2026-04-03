import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../services/firebase_service.dart';
import '../welcome_screen.dart';
import 'create_event_screen.dart';
import 'manage_event_screen.dart';
import 'organizer_profile_screen.dart';
import 'participants_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  State<OrganizerDashboardScreen> createState() =>
      _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedBottomTab = 0;

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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date TBD';
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool _canDeleteEvent(DateTime? eventDate) {
    if (eventDate == null) return true;
    final deleteCutoff = eventDate.subtract(const Duration(hours: 12));
    return DateTime.now().isBefore(deleteCutoff);
  }

  bool _canEditEvent(DateTime? eventDate) {
    if (eventDate == null) return true;
    return DateTime.now().isBefore(eventDate);
  }

  bool _isOwnedByCurrentUser(Map<String, dynamic> event, String currentUid) {
    if (currentUid.isEmpty) return true;
    final ownerCandidates = [
      event['createdByUid'],
      event['organizerId'],
      event['userId'],
      event['ownerId'],
    ];

    for (final candidate in ownerCandidates) {
      if ((candidate?.toString() ?? '') == currentUid) {
        return true;
      }
    }

    // If no ownership field exists, keep events visible so dashboard is useful.
    final hasOwnerMetadata = ownerCandidates.any((value) => value != null);
    return !hasOwnerMetadata;
  }

  String _statusForEvent(Map<String, dynamic> event) {
    final status = _asString(event['status']).toLowerCase();
    if (status == 'draft' || status == 'completed' || status == 'active') {
      return status;
    }

    final date = _asDate(
      event['eventDate'] ?? event['date'] ?? event['startDate'],
    );
    if (date == null) return 'draft';
    if (date.isBefore(DateTime.now())) return 'completed';
    return 'active';
  }

  Color _statusBackground(String status, bool isDark) {
    switch (status) {
      case 'active':
        return _kPrimaryColor.withValues(alpha: 0.14);
      case 'completed':
        return isDark ? Colors.grey.shade700 : Colors.grey.shade300;
      default:
        return isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    }
  }

  Color _statusText(String status, bool isDark) {
    switch (status) {
      case 'active':
        return _kPrimaryColor;
      case 'completed':
        return isDark ? Colors.grey.shade300 : Colors.grey.shade700;
      default:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await _firebaseService.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to sign out: $e')));
    }
  }

  Future<void> _confirmAndDeleteEvent(Map<String, dynamic> event) async {
    final eventId = _asString(event['id']);
    final eventDate = _asDate(
      event['eventDate'] ?? event['date'] ?? event['startDate'],
    );
    if (eventId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete: missing event id.')),
      );
      return;
    }

    if (!_canDeleteEvent(eventDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Events cannot be deleted within 12 hours of start.'),
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Event'),
          content: const Text('Do you want to delete this event?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      final imageUrl = _asString(
        event['imageUrl'] ?? event['bannerUrl'] ?? event['photoUrl'],
      );

      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .delete();

      if (imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (_) {
          // Event data is already deleted; ignore storage cleanup failures.
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
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
            Icon(Icons.dashboard, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firebaseService.streamOrganizerEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load organizer dashboard right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
            );
          }

          final currentUid = _firebaseService.currentUser?.uid ?? '';
          final allEvents = snapshot.data ?? const <Map<String, dynamic>>[];
          final myEvents = allEvents
              .where((event) => _isOwnedByCurrentUser(event, currentUid))
              .toList();

          myEvents.sort((a, b) {
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

          final totalEvents = myEvents.length;
          final totalAttendees = myEvents.fold<int>(0, (acc, event) {
            return acc +
                _asInt(
                  event['participantsCount'] ??
                      event['participantCount'] ??
                      event['joinedCount'],
                );
          });

          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _signOut(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kPrimaryColor,
                          side: BorderSide(
                            color: _kPrimaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width >= 720
                          ? 2
                          : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _StatCard(
                          label: 'Total Events',
                          value: '$totalEvents',
                          isDark: isDark,
                        ),
                        _StatCard(
                          label: 'Total Attendees',
                          value: '$totalAttendees',
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'My Events',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (myEvents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          'No events yet. Tap Create Event to start your first event.',
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ...myEvents.map((event) {
                        final title = _asString(
                          event['title'] ?? event['eventName'] ?? event['name'],
                          fallback: 'Untitled Event',
                        );
                        final imageUrl = _asString(
                          event['imageUrl'] ??
                              event['bannerUrl'] ??
                              event['photoUrl'],
                        );
                        final location = _asString(
                          event['location'] ??
                              event['venue'] ??
                              event['address'],
                          fallback: 'Location TBD',
                        );
                        final participants = _asInt(
                          event['participantsCount'] ??
                              event['participantCount'] ??
                              event['joinedCount'],
                        );
                        final date = _asDate(
                          event['eventDate'] ??
                              event['date'] ??
                              event['startDate'],
                        );
                        final status = _statusForEvent(event);
                        final canDelete =
                            status == 'active' && _canDeleteEvent(date);
                        final canEdit = _canEditEvent(date);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade800.withValues(
                                        alpha: 0.6,
                                      )
                                    : Colors.grey.shade200.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.10,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Image Section - Large and Prominent
                                if (imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 3 / 1.8,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder:
                                                (_, error, stackTrace) {
                                                  return Container(
                                                    color: isDark
                                                        ? Colors.grey.shade700
                                                        : Colors.grey.shade300,
                                                    child: Center(
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        size: 48,
                                                        color: isDark
                                                            ? Colors
                                                                  .grey
                                                                  .shade600
                                                            : Colors
                                                                  .grey
                                                                  .shade400,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 60,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withValues(
                                                      alpha: 0.2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Details Section
                                Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Status Badge
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusBackground(
                                                status,
                                                isDark,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                                color: _statusText(
                                                  status,
                                                  isDark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          InkWell(
                                            onTap: () {
                                              if (!canDelete) {
                                                final deleteMessage =
                                                    status != 'active'
                                                    ? 'Only active events can be deleted.'
                                                    : 'Events cannot be deleted within 12 hours of start.';
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      deleteMessage,
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              _confirmAndDeleteEvent(event);
                                            },
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    (canDelete
                                                            ? Colors.red
                                                            : Colors.grey)
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color:
                                                      (canDelete
                                                              ? Colors.red
                                                              : Colors.grey)
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.delete_outline,
                                                    size: 14,
                                                    color: canDelete
                                                        ? Colors.red
                                                        : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: canDelete
                                                          ? Colors.red
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Event Title
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),

                                      // Event Metadata (Date, Participants, Location)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _EventDetailRow(
                                            icon: Icons.calendar_today,
                                            text: _formatDate(date),
                                            isDark: isDark,
                                          ),
                                          const SizedBox(height: 8),
                                          _EventDetailRow(
                                            icon: Icons.group,
                                            text: '$participants Participants',
                                            isDark: isDark,
                                          ),
                                          const SizedBox(height: 8),
                                          _EventDetailRow(
                                            icon: Icons.location_on,
                                            text: location,
                                            isDark: isDark,
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 16),

                                      // Action Buttons
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              final selectedEvent =
                                                  Map<String, dynamic>.from(
                                                    event,
                                                  );
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ParticipantsScreen(
                                                        eventData:
                                                            selectedEvent,
                                                      ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _kPrimaryColor,
                                              foregroundColor: Colors.black,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              elevation: 2,
                                            ),
                                            icon: const Icon(
                                              Icons.people,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Participants',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: () {
                                              if (!canEdit) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Events cannot be edited after the event date.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ManageEventScreen(
                                                        eventData: event,
                                                      ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: canEdit
                                                  ? _kPrimaryColor
                                                  : Colors.grey,
                                              foregroundColor: canEdit
                                                  ? Colors.black
                                                  : Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              elevation: 2,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Manage Event',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: canEdit
                                                        ? Colors.black
                                                        : Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward,
                                                  size: 18,
                                                  color: canEdit
                                                      ? Colors.black
                                                      : Colors.white,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomTab,
        onTap: (index) {
          if (index == 0) {
            setState(() => _selectedBottomTab = index);
            return;
          }

          if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CreateEventScreen()),
            );
            return;
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrganizerProfileScreen()),
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kPrimaryColor,
        unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[700],
        backgroundColor: isDark ? _kBackgroundDark : Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create Event',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.55)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailRow extends StatelessWidget {
  const _EventDetailRow({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  final IconData icon;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _kPrimaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
