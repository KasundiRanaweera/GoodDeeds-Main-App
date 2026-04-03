import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_event_screen.dart';
import 'organizer_dashboard_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({super.key});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _seeded = false;
  bool _isSaving = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  String _asTrimmedString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _profileDisplayName() {
    final current = _nameController.text.trim();
    return current.isEmpty ? 'Organizer' : current;
  }

  void _navigateFromBottomNav(int index) {
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
      );
      return;
    }

    if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreateEventScreen()),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (value is String) date = DateTime.tryParse(value);
    if (date == null) return 'Not available';

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

  Future<void> _saveDetails() async {
    final user = _user;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      await _usersCollection.doc(user.uid).set({
        'name': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(name);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Updated'),
            content: const Text('Details updated successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update details: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? _kBackgroundDark : _kBackgroundLight,
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          title: const Text('My Profile'),
          backgroundColor: isDark
              ? _kBackgroundDark.withValues(alpha: 0.84)
              : Colors.white.withValues(alpha: 0.86),
          foregroundColor: isDark ? Colors.white : Colors.black,
        ),
        body: const Center(child: Text('Please sign in again.')),
      );
    }

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
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _usersCollection.doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = _asTrimmedString(
            data['name'],
            fallback: _asTrimmedString(user.displayName),
          );
          final email = _asTrimmedString(
            data['email'],
            fallback: user.email ?? '',
          );
          final phone = _asTrimmedString(data['phone']);
          final joinedDate = _formatDate(data['createdAt']);

          if (!_seeded) {
            _nameController.text = name;
            _phoneController.text = phone;
            _seeded = true;
          }

          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 106),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade900.withValues(alpha: 0.55)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _kPrimaryColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: _kPrimaryColor.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: _kPrimaryColor,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profileDisplayName(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Organizer',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _editableTile(
                        label: 'Full Name',
                        controller: _nameController,
                        isDark: isDark,
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Full name is required';
                          }
                          return null;
                        },
                      ),
                      _infoTile(
                        label: 'Email',
                        value: email.isEmpty ? 'Not provided' : email,
                        isDark: isDark,
                      ),
                      _editableTile(
                        label: 'Contact Number',
                        controller: _phoneController,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Contact number is required';
                          }
                          return null;
                        },
                      ),
                      _infoTile(
                        label: 'Joined Date',
                        value: joinedDate,
                        isDark: isDark,
                      ),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isSaving ? 'Updating...' : 'Update Details',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
        onTap: _navigateFromBottomNav,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kPrimaryColor,
        unselectedItemColor: isDark
            ? Colors.grey.shade500
            : Colors.grey.shade700,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
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

  Widget _editableTile({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.45)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: isDark
                  ? Colors.grey.shade800.withValues(alpha: 0.55)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _kPrimaryColor.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _kPrimaryColor.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: _kPrimaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.45)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}