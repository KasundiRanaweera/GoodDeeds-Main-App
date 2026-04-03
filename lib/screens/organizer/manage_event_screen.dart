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

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class ManageEventScreen extends StatefulWidget {
  const ManageEventScreen({super.key, required this.eventData});

  final Map<String, dynamic> eventData;

  @override
  State<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends State<ManageEventScreen> {
  static const double _kMaxImageWidth = 1600;
  static const double _kMaxImageHeight = 1600;
  static const int _kImageQuality = 80;

  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _organizerNameController;
  late final TextEditingController _eventTitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _pointsController;
  late final TextEditingController _contactNumberController;

  final List<String> _categories = kOrganizerEventCategories;

  late String _selectedCategory;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isUploadingImage = false;
  late String _currentImageUrl;
  String _selectedImageExtension = 'jpg';
  String _selectedImageContentType = 'image/jpeg';
  DateTime? _originalEventDate;

  bool get _canUseCamera =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isMobileUploadPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _eventId => widget.eventData['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();

    final displayName = _firebaseService.currentUser?.displayName?.trim() ?? '';
    final organizerName = _asString(
      widget.eventData['organizerName'] ??
          widget.eventData['createdByName'] ??
          displayName,
      fallback: 'Organizer',
    );

    _organizerNameController = TextEditingController(text: organizerName);
    _eventTitleController = TextEditingController(
      text: _asString(
        widget.eventData['title'] ??
            widget.eventData['eventName'] ??
            widget.eventData['name'],
      ),
    );
    _descriptionController = TextEditingController(
      text: _asString(widget.eventData['description']),
    );
    _locationController = TextEditingController(
      text: _asString(
        widget.eventData['location'] ??
            widget.eventData['venue'] ??
            widget.eventData['address'],
      ),
    );
    _pointsController = TextEditingController(
      text: () {
        final initial = _asInt(
          widget.eventData['impactPoints'] ??
              widget.eventData['points'] ??
              widget.eventData['rewardPoints'],
          fallback: 50,
        );
        if (initial < 50) return '50';
        if (initial > 200) return '200';
        return initial.toString();
      }(),
    );
    _contactNumberController = TextEditingController(
      text: _asString(
        widget.eventData['contactNumber'] ?? widget.eventData['phone'],
      ),
    );
    _currentImageUrl = _asString(
      widget.eventData['imageUrl'] ??
          widget.eventData['bannerUrl'] ??
          widget.eventData['photoUrl'],
    );

    final rawCategory = _asString(widget.eventData['category']);
    if (rawCategory.isNotEmpty && !_categories.contains(rawCategory)) {
      _categories.add(rawCategory);
    }
    _selectedCategory = rawCategory.isEmpty ? _categories.first : rawCategory;

    final parsedDate = _asDate(
      widget.eventData['eventDate'] ??
          widget.eventData['date'] ??
          widget.eventData['startDate'],
    );
    if (parsedDate != null) {
      _originalEventDate = parsedDate;
      _selectedDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
      _selectedTime = TimeOfDay(
        hour: parsedDate.hour,
        minute: parsedDate.minute,
      );
    }
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
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic date = value?.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
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

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) return;
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Silently fail on deletion - don't interrupt the save flow
      debugPrint('Failed to delete old image: $e');
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time.')),
      );
      return;
    }
    if (_eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event ID is missing. Cannot update event.'),
        ),
      );
      return;
    }
    if (_originalEventDate != null &&
        DateTime.now().isAfter(_originalEventDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event is completed and can’t be edited.'),
        ),
      );
      return;
    }

    final selectedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    setState(() => _isSaving = true);
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

      String imageUrlToSave = _currentImageUrl;
      if (_selectedImage != null || _selectedImageBytes != null) {
        // Delete old image before uploading new one
        await _deleteImageFromStorage(_currentImageUrl);
        final uploadedUrl = await _uploadSelectedImageToStorage();
        if (uploadedUrl == null || !mounted) return;
        imageUrlToSave = uploadedUrl;
      }

      // Validate all required fields
      final organizerName = _organizerNameController.text.trim();
      final title = _eventTitleController.text.trim();
      final description = _descriptionController.text.trim();
      final location = _locationController.text.trim();

      if (organizerName.isEmpty ||
          title.isEmpty ||
          description.isEmpty ||
          location.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields.')),
        );
        return;
      }

      // Update event with all fields
      await FirebaseFirestore.instance
          .collection('events')
          .doc(_eventId)
          .update({
            'organizerName': organizerName,
            'createdByName': organizerName,
            'title': title,
            'description': description,
            'category': _selectedCategory,
            'impactPoints': points,
            'location': location,
            'contactNumber': _contactNumberController.text.trim(),
            'imageUrl': imageUrlToSave,
            'eventDate': Timestamp.fromDate(selectedDateTime),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      debugPrint('Event updated successfully: $_eventId');

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Event Updated'),
            content: const Text('Event edited successfully.'),
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
      ).showSnackBar(SnackBar(content: Text('Failed to save changes: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit, color: _kPrimaryColor),
            SizedBox(width: 8),
            Text('Edit Event', style: TextStyle(fontWeight: FontWeight.w800)),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
            children: [
              _label('Organizer Name', isDark),
              _field(
                controller: _organizerNameController,
                hintText: 'Green Earth Foundation',
                isDark: isDark,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Organizer name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Event Title', isDark),
              _field(
                controller: _eventTitleController,
                hintText: 'Annual Charity Marathon',
                isDark: isDark,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Event title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Description', isDark),
              _field(
                controller: _descriptionController,
                hintText: 'Describe your event',
                isDark: isDark,
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
                        _label('Category', isDark),
                        _dropdownField(isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Points Reward', isDark),
                        _field(
                          controller: _pointsController,
                          hintText: '50 - 200',
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(top: 18, right: 12),
                            child: Text(
                              'points',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
              _label('Location', isDark),
              _field(
                controller: _locationController,
                hintText: 'Central Park Arena',
                isDark: isDark,
                prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _label('Contact Number', isDark),
              _field(
                controller: _contactNumberController,
                hintText: 'e.g. 0712345678',
                isDark: isDark,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Contact number is required';
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
                        _label('Date', isDark),
                        _pickerField(
                          onTap: _pickDate,
                          label: _dateLabel(),
                          icon: Icons.calendar_today,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Time', isDark),
                        _pickerField(
                          onTap: _pickTime,
                          label: _timeLabel(),
                          icon: Icons.schedule,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _label('Event Banner', isDark),
              InkWell(
                onTap: _isUploadingImage ? null : _selectImage,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 180,
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
                      : _currentImageUrl.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _currentImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stackTrace) {
                                  return _imagePlaceholder(isDark);
                                },
                              ),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.2),
                              child: const Center(
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ],
                        )
                      : _imagePlaceholder(isDark),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    shadowColor: _kPrimaryColor.withValues(alpha: 0.22),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Edit Event',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownField(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          items: _categories
              .map(
                (item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedCategory = value);
          },
        ),
      ),
    );
  }

  Widget _pickerField({
    required VoidCallback onTap,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey.shade800.withValues(alpha: 0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kPrimaryColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade500, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: label.startsWith('Select')
                      ? (isDark ? Colors.grey.shade400 : Colors.grey.shade500)
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    FormFieldValidator<String>? validator,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
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

  String _dateLabel() {
    final date = _selectedDate;
    if (date == null) return 'Select date';
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

  Widget _imagePlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate, color: _kPrimaryColor, size: 42),
        const SizedBox(height: 8),
        const Text(
          'Select event image',
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

  String _timeLabel() {
    final time = _selectedTime;
    if (time == null) return 'Select time';
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }
}
