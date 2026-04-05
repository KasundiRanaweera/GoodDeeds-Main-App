import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/firebase_service.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  bool _isSaving = false;
  File? _selectedImage;
  bool _isUploadingImage = false;
  late String _currentPhotoUrl;

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Future<void> _loadCurrentProfile() async {
    final user = _firebaseService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final data = await _firebaseService.getMergedUserData(user.uid);
      _nameController.text = _asString(
        data['name'] ?? user.displayName,
        fallback: 'Community Volunteer',
      );
      _phoneController.text = _asString(data['phone']);
      _addressController.text = _asString(data['address']);
      _bioController.text = _asString(data['bio']);
      _currentPhotoUrl = _asString(data['photoUrl'] ?? data['avatarUrl']);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load profile details.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectPhoto() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Photo Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: _kPrimaryColor),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final image = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null && mounted) {
                    setState(() => _selectedImage = File(image.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: _kPrimaryColor),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final image = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null && mounted) {
                    setState(() => _selectedImage = File(image.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadPhotoToStorage(File imageFile) async {
    try {
      setState(() => _isUploadingImage = true);

      final user = _firebaseService.currentUser;
      if (user == null) return null;

      // Use the same bucket path family permitted by current Storage rules.
      final fileName =
          'events/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      await uploadTask;

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _deletePhotoFromStorage(String photoUrl) async {
    try {
      if (photoUrl.isEmpty) return;
      final ref = FirebaseStorage.instance.refFromURL(photoUrl);
      await ref.delete();
    } catch (e) {
      // Silently fail on deletion - don't interrupt the save flow
      debugPrint('Failed to delete old photo: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _firebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to edit profile.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String photoUrlToSave = _currentPhotoUrl;
      if (_selectedImage != null) {
        // Delete old photo before uploading new one
        await _deletePhotoFromStorage(_currentPhotoUrl);
        final uploadedUrl = await _uploadPhotoToStorage(_selectedImage!);
        if (uploadedUrl == null || !mounted) return;
        photoUrlToSave = uploadedUrl;
      }

      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .set({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'bio': _bioController.text.trim(),
            'photoUrl': photoUrlToSave,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Keep legacy user-list screens in sync while profile data lives in
      // user_profiles.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'photoUrl': photoUrlToSave,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Profile Updated'),
            content: const Text('Your profile was updated successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
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
            Icon(Icons.edit, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 132,
                                    height: 132,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _kPrimaryColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 4,
                                      ),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipOval(
                                          child: _selectedImage != null
                                              ? Image.file(
                                                  _selectedImage!,
                                                  fit: BoxFit.cover,
                                                )
                                              : _currentPhotoUrl.isNotEmpty
                                              ? Image.network(
                                                  _currentPhotoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, error, stackTrace) {
                                                        return _EditAvatarFallback(
                                                          initials: _initials(
                                                            _nameController
                                                                .text,
                                                          ),
                                                        );
                                                      },
                                                )
                                              : _EditAvatarFallback(
                                                  initials: _initials(
                                                    _nameController.text,
                                                  ),
                                                ),
                                        ),
                                        if (_isUploadingImage)
                                          Container(
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black54,
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: _kPrimaryColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _isUploadingImage
                                        ? null
                                        : _selectPhoto,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: _kPrimaryColor.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                      foregroundColor: _kPrimaryColor,
                                      backgroundColor: _kPrimaryColor
                                          .withValues(alpha: 0.1),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.photo_camera,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Upload Photo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Full Name',
                            child: TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                isDark,
                                hintText: 'e.g. Alex Johnson',
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                          ),
                          _LabeledField(
                            label: 'Phone Number',
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                isDark,
                                hintText: '+1 (555) 000-0000',
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Address',
                            child: TextFormField(
                              controller: _addressController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                isDark,
                                hintText: '123 Design St, Creative City',
                              ),
                            ),
                          ),
                          _LabeledField(
                            label: 'Bio',
                            child: TextFormField(
                              controller: _bioController,
                              keyboardType: TextInputType.multiline,
                              minLines: 5,
                              maxLines: 6,
                              decoration: _inputDecoration(
                                isDark,
                                hintText: 'Tell us about yourself...',
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kPrimaryColor,
                                  foregroundColor: Colors.black,
                                  elevation: 6,
                                  shadowColor: _kPrimaryColor.withValues(
                                    alpha: 0.25,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Text(
                                        'Update Profile',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: isDark ? Colors.grey.shade800 : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kPrimaryColor.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kPrimaryColor.withValues(alpha: 0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _kPrimaryColor, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EditAvatarFallback extends StatelessWidget {
  const _EditAvatarFallback({required this.initials});

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
