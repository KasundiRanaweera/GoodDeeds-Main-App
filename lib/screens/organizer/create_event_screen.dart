import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../constants/event_categories.dart';
import '../../services/firebase_service.dart';
import 'organizer_dashboard_screen.dart';
import 'organizer_profile_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF051A08);

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  static const double _kMaxImageWidth = 1600;
  static const double _kMaxImageHeight = 1600;
  static const int _kImageQuality = 80;

  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _organizerNameController =
      TextEditingController();
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();

  late final List<String> _categories = kOrganizerEventCategories;

  late String _selectedCategory = kOrganizerEventCategories[0];
  DateTime? _selectedDateTime;
  bool _isSubmitting = false;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isUploadingImage = false;
  String _selectedImageExtension = 'jpg';
  String _selectedImageContentType = 'image/jpeg';

  bool get _canUseCamera =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isMobileUploadPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    final displayName = _firebaseService.currentUser?.displayName?.trim() ?? '';
    _organizerNameController.text = displayName;
    _pointsController.text = '50';
  }

  @override
  void dispose() {
    _organizerNameController.dispose();
    _eventTitleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _pointsController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDateTime ?? now.add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _selectImage() async {
    if (!_isMobileUploadPlatform) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploads are supported on mobile only.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: _kPrimaryColor),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickImageFromSource(ImageSource.gallery);
                },
              ),
              if (_canUseCamera)
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: _kPrimaryColor),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickImageFromSource(ImageSource.camera);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _updateImageMetadata(XFile image) {
    final imageName = image.name.isNotEmpty ? image.name : image.path;
    final dotIndex = imageName.lastIndexOf('.');
    final rawExtension = dotIndex == -1
        ? 'jpg'
        : imageName.substring(dotIndex + 1).toLowerCase();

    const mimeByExt = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'heic': 'image/heic',
      'heif': 'image/heif',
    };

    _selectedImageExtension = rawExtension;
    _selectedImageContentType = mimeByExt[rawExtension] ?? 'image/jpeg';
  }

  Uint8List _optimizeImageBytes(Uint8List originalBytes) {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      return originalBytes;
    }

    var output = decoded;
    if (decoded.width > _kMaxImageWidth || decoded.height > _kMaxImageHeight) {
      output = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? _kMaxImageWidth.toInt() : null,
        height: decoded.height > decoded.width
            ? _kMaxImageHeight.toInt()
            : null,
        interpolation: img.Interpolation.average,
      );
    }

    final encoded = img.encodeJpg(output, quality: _kImageQuality);
    return Uint8List.fromList(encoded);
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    if (!_isMobileUploadPlatform) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploads are supported on mobile only.'),
        ),
      );
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: _kMaxImageWidth,
        maxHeight: _kMaxImageHeight,
        imageQuality: _kImageQuality,
      );
      if (image == null || !mounted) return;

      _updateImageMetadata(image);

      final rawBytes = await image.readAsBytes();
      final optimizedBytes = _optimizeImageBytes(rawBytes);
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = optimizedBytes;
        _selectedImage = File(image.path);
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not access image source: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image selection failed: $e')));
    }
  }

  Future<String?> _uploadSelectedImageToStorage({
    FirebaseStorage? storageOverride,
    bool allowLegacyBucketRetry = true,
  }) async {
    try {
      setState(() => _isUploadingImage = true);

      final user = _firebaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final storage = storageOverride ?? FirebaseStorage.instance;

      final fileName =
          'events/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.$_selectedImageExtension';
      final ref = storage.ref().child(fileName);

      debugPrint('=== Starting image upload ===');
      debugPrint('User UID: ${user.uid}');
      debugPrint('File path: $fileName');
      debugPrint('Storage bucket: ${storage.app.options.storageBucket}');

      final UploadTask uploadTask;
      final imageFile = _selectedImage;
      if (!_isMobileUploadPlatform) {
        throw Exception('Image uploads are supported on mobile only.');
      }
      if (imageFile == null || !imageFile.existsSync()) {
        throw Exception('No valid image file available for upload.');
      }
      final uploadBytesEstimate = imageFile.lengthSync();
      debugPrint('Mobile file upload: file size = $uploadBytesEstimate');
      uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: _selectedImageContentType,
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (mounted) {
            final totalBytes = snapshot.totalBytes;
            if (totalBytes <= 0) {
              debugPrint(
                'Upload progress: waiting for total bytes... state=${snapshot.state}',
              );
              return;
            }
            final progress = (snapshot.bytesTransferred / totalBytes * 100)
                .toInt();
            debugPrint('Upload progress: $progress%');
          }
        },
        onError: (Object e) {
          debugPrint('Upload stream error: $e');
        },
      );

      // Wait for upload with timeout
      final estimatedMb = uploadBytesEstimate / (1024 * 1024);
      final timeoutSeconds = (60 + (estimatedMb * 45).ceil())
          .clamp(180, 900)
          .toInt();
      debugPrint(
        'Waiting for upload to complete (timeout: ${timeoutSeconds}s, size: ${estimatedMb.toStringAsFixed(2)} MB)...',
      );
      await uploadTask.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw Exception(
            'Upload timeout - took longer than ${timeoutSeconds}s. Please check your connection and try again.',
          );
        },
      );

      debugPrint('Upload complete, getting download URL...');

      // Get and verify download URL
      final downloadUrl = await ref.getDownloadURL();
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL for uploaded image');
      }

      debugPrint('Image uploaded successfully: $downloadUrl');
      debugPrint('=== Upload finished successfully ===');
      return downloadUrl;
    } catch (e, st) {
      debugPrint('=== Image upload error ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $st');

      if (e is FirebaseException &&
          e.code == 'bucket-not-found' &&
          allowLegacyBucketRetry) {
        final configuredBucket =
            (storageOverride ?? FirebaseStorage.instance)
                .app
                .options
                .storageBucket ??
            '';
        if (configuredBucket.endsWith('.firebasestorage.app')) {
          final legacyBucket = configuredBucket.replaceFirst(
            '.firebasestorage.app',
            '.appspot.com',
          );
          debugPrint('Retrying upload with legacy bucket: $legacyBucket');
          return _uploadSelectedImageToStorage(
            storageOverride: FirebaseStorage.instanceFor(
              bucket: 'gs://$legacyBucket',
            ),
            allowLegacyBucketRetry: false,
          );
        }
      }

      if (mounted) {
        final userMessage = _buildUploadErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  String _buildUploadErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('bucket-not-found')) {
      return 'Firebase Storage bucket not found. Enable Storage in Firebase Console or verify storageBucket in firebase_options.dart.';
    }
    if (raw.contains('code: -13040') || raw.contains('storage/canceled')) {
      return 'Upload was canceled before completion. Keep this page open, check emulator internet, and try again.';
    }
    if (raw.contains('storage/unauthorized') ||
        raw.contains('permission-denied')) {
      return 'Upload blocked by Firebase rules. Publish Storage rules and sign in again.';
    }
    if (raw.contains('storage/retry-limit-exceeded')) {
      return 'Upload failed after multiple retries. Please check your network and try a smaller image.';
    }
    if (raw.contains('timeout')) {
      return 'Upload took too long. Please check your connection and retry.';
    }
    return 'Failed to upload image: $error';
  }

  String _dateTimeLabel() {
    final date = _selectedDateTime;
    if (date == null) return 'Select date and time';

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
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$month ${date.day}, ${date.year}  $hour12:$minute $suffix';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time.')),
      );
      return;
    }
    if (_selectedImage == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event image.')),
      );
      return;
    }

    final user = _firebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final points = int.tryParse(_pointsController.text.trim()) ?? 0;
      if (points < 50 || points > 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reward points must be between 50 and 200.'),
          ),
        );
        return;
      }

      // Upload image and get download URL
      final imageUrl = await _uploadSelectedImageToStorage();
      if (imageUrl == null || !mounted) return;

      // Validate all required fields
      final title = _eventTitleController.text.trim();
      final description = _descriptionController.text.trim();
      final location = _locationController.text.trim();
      final contactNumber = _contactNumberController.text.trim();
      final organizerName = _organizerNameController.text.trim();

      if (title.isEmpty ||
          description.isEmpty ||
          location.isEmpty ||
          organizerName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields.')),
        );
        return;
      }

      // Create event data with all required and optional fields
      final data = <String, dynamic>{
        // Required fields
        'title': title,
        'description': description,
        'location': location,
        'contactNumber': contactNumber,
        'category': _selectedCategory,
        'impactPoints': points,
        'eventDate': Timestamp.fromDate(_selectedDateTime!),
        'imageUrl': imageUrl,
        'organizerName': organizerName,
        'createdByUid': user.uid,
        'createdByName': organizerName,
        // Participant tracking
        'participantsCount': 0,
        'participantIds': <String>[],
        'checkedInIds': <String>[],
        'awardedParticipantIds': <String>[],
        // Status and timestamps
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Store in Firestore with error handling
      final docRef = await FirebaseFirestore.instance
          .collection('events')
          .add(data);

      debugPrint('Event created successfully with ID: ${docRef.id}');

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text('Event created successfully.'),
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create event: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
            Icon(Icons.add_circle, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('Create Event', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        backgroundColor: isDark
            ? _kBackgroundDark.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.86),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 98),
            children: [
              const Text(
                'Event Banner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _isUploadingImage ? null : _selectImage,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _kPrimaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    color: _kPrimaryColor.withValues(alpha: 0.06),
                  ),
                  child: (_selectedImage != null || _selectedImageBytes != null)
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _selectedImageBytes != null
                                  ? Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            if (_isUploadingImage)
                              Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: _kPrimaryColor,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : _bannerPlaceholder(isDark),
                ),
              ),
              const SizedBox(height: 16),
              _label('Organization Name'),
              _field(
                controller: _organizerNameController,
                hintText: 'e.g. Green Earth Foundation',
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Organizer name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Event Title'),
              _field(
                controller: _eventTitleController,
                hintText: 'e.g. Beach Cleanup Drive',
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Event title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Description'),
              _field(
                controller: _descriptionController,
                hintText: 'What is the event about?',
                minLines: 5,
                maxLines: 6,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Category'),
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade800.withValues(alpha: 0.5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _kPrimaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedCategory,
                              items: _categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedCategory = value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Points Reward'),
                        _field(
                          controller: _pointsController,
                          hintText: '50 - 200',
                          keyboardType: TextInputType.number,
                          suffixIcon: const Icon(
                            Icons.stars,
                            color: _kPrimaryColor,
                          ),
                          validator: (value) {
                            final points = int.tryParse((value ?? '').trim());
                            if (points == null) {
                              return 'Required';
                            }
                            if (points < 50 || points > 200) {
                              return 'Use 50-200';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _label('Location'),
              _field(
                controller: _locationController,
                hintText: 'Add event location',
                suffixIcon: const Icon(Icons.map, color: _kPrimaryColor),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Contact Number'),
              _field(
                controller: _contactNumberController,
                hintText: 'e.g. 071 234 5678',
                keyboardType: TextInputType.phone,
                suffixIcon: const Icon(Icons.phone, color: _kPrimaryColor),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Contact number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Date & Time'),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDateTime,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _kPrimaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateTimeLabel(),
                          style: TextStyle(
                            color: _selectedDateTime == null
                                ? (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500)
                                : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: _kPrimaryColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    shadowColor: _kPrimaryColor.withValues(alpha: 0.24),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Create Event',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.rocket_launch),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const OrganizerDashboardScreen(),
              ),
            );
            return;
          }

          if (index == 1) {
            return;
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrganizerProfileScreen()),
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kPrimaryColor,
        unselectedItemColor: isDark
            ? Colors.grey.shade500
            : Colors.grey.shade700,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Create Event',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _bannerPlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate, color: _kPrimaryColor, size: 42),
        const SizedBox(height: 8),
        const Text(
          'Upload event image',
          style: TextStyle(color: _kPrimaryColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Recommended: 1200 x 675 px',
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hintText,
    FormFieldValidator<String>? validator,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.white,
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
          borderSide: BorderSide(color: _kPrimaryColor),
        ),
      ),
    );
  }
}
