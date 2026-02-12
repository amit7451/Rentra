import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';

class EditHostelScreen extends StatefulWidget {
  final HostelModel hostel;
  const EditHostelScreen({super.key, required this.hostel});

  @override
  State<EditHostelScreen> createState() => _EditHostelScreenState();
}

class _EditHostelScreenState extends State<EditHostelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _cloudinaryService = CloudinaryService.instance;
  final _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _priceController;
  late final TextEditingController _availableRoomsController;
  late final TextEditingController _ratingController;
  late final TextEditingController _totalReviewsController;
  final TextEditingController _amenityController = TextEditingController();

  late List<String> _existingImageUrls;  // Already uploaded to Cloudinary
  final List<File> _newSelectedImages = []; // New images to upload
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isCloudinaryReady = false;
  late List<String> _amenities;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _checkCloudinaryStatus();

    final h = widget.hostel;
    _nameController = TextEditingController(text: h.name);
    _descriptionController = TextEditingController(text: h.description);
    _addressController = TextEditingController(text: h.address);
    _cityController = TextEditingController(text: h.city);
    _countryController = TextEditingController(text: h.country);
    _priceController = TextEditingController(text: h.pricePerNight.toString());
    _availableRoomsController = TextEditingController(
      text: h.availableRooms.toString(),
    );
    _ratingController = TextEditingController(text: h.rating.toString());
    _totalReviewsController = TextEditingController(
      text: h.totalReviews.toString(),
    );
    _existingImageUrls = List.from(h.images);
    _amenities = List.from(h.amenities);
    _isActive = h.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _priceController.dispose();
    _availableRoomsController.dispose();
    _ratingController.dispose();
    _totalReviewsController.dispose();
    _amenityController.dispose();
    super.dispose();
  }

  Future<void> _checkCloudinaryStatus() async {
    if (!mounted) return;

    setState(() {
      _isCloudinaryReady = CloudinaryService.isInitialized;
    });

    if (!_isCloudinaryReady) {
      try {
        await CloudinaryService.initialize();
        if (mounted) {
          setState(() {
            _isCloudinaryReady = true;
          });
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Image upload service not available', isError: true);
        }
      }
    }
  }

  // ── Image Picker Methods ─────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        if (pickedFiles.length + _existingImageUrls.length + _newSelectedImages.length > 10) {
          _showSnack('Maximum 10 images total allowed', isError: true);
          return;
        }

        setState(() {
          _newSelectedImages.addAll(pickedFiles.map((file) => File(file.path)));
        });
      }
    } catch (e) {
      _showSnack('Failed to pick images', isError: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (_existingImageUrls.length + _newSelectedImages.length >= 10) {
          _showSnack('Maximum 10 images total allowed', isError: true);
          return;
        }

        setState(() {
          _newSelectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      _showSnack('Failed to take photo', isError: true);
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImages();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.green),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newSelectedImages.removeAt(index);
    });
  }

  // ── Save Method ─────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_existingImageUrls.isEmpty && _newSelectedImages.isEmpty) {
      _showSnack('Please add at least one image', isError: true);
      return;
    }

    if (!_isCloudinaryReady && _newSelectedImages.isNotEmpty) {
      await _checkCloudinaryStatus();
      if (!_isCloudinaryReady) {
        _showSnack('Upload service not available', isError: true);
        return;
      }
    }

    setState(() => _isUploading = true);

    try {
      List<String> allImageUrls = [..._existingImageUrls];

      // Upload new images if any
      if (_newSelectedImages.isNotEmpty) {
        final uploadedUrls = await _cloudinaryService.uploadMultipleImages(_newSelectedImages);
        allImageUrls.addAll(uploadedUrls);
      }

      setState(() => _isLoading = true);

      final updated = widget.hostel.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        pricePerNight: double.parse(_priceController.text),
        availableRooms: int.parse(_availableRoomsController.text),
        rating: double.parse(_ratingController.text),
        totalReviews: int.parse(_totalReviewsController.text),
        images: allImageUrls,
        amenities: _amenities,
        isActive: _isActive,
      );

      await _firestoreService.updateHostel(updated);

      if (mounted) {
        _showSnack('Hostel updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Update failed: ${e.toString().replaceAll('Exception:', '')}',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isLoading = false;
        });
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Hostel'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: (_isLoading || _isUploading) ? null : _save,
            child: Text(
              _isUploading ? 'Uploading...' : 'Save',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading || _isUploading
          ? LoadingIndicator(
        message: _isUploading
            ? 'Uploading images...'
            : 'Saving changes...',
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Active Toggle ─────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _isActive
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isActive
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isActive
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: _isActive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Listing Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _isActive
                                ? 'Active – visible to renters'
                                : 'Inactive – hidden from search',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _sectionTitle('Basic Information'),
              const SizedBox(height: 14),
              _field(
                _nameController,
                'Hostel Name',
                'Name',
                validator: _req('name'),
              ),
              const SizedBox(height: 14),
              _field(
                _descriptionController,
                'Description',
                'Describe your hostel',
                maxLines: 4,
                validator: _req('description'),
              ),
              const SizedBox(height: 24),

              _sectionTitle('Location'),
              const SizedBox(height: 14),
              _field(
                _addressController,
                'Address',
                'Street address',
                validator: _req('address'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _cityController,
                      'City',
                      'City',
                      validator: _req('city'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _field(
                      _countryController,
                      'Country',
                      'Country',
                      validator: _req('country'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionTitle('Pricing & Availability'),
              const SizedBox(height: 14),
              _field(
                _priceController,
                'Price Per Year (₹)',
                'e.g. 50000',
                keyboardType: TextInputType.number,
                validator: _numVal('price'),
              ),
              const SizedBox(height: 14),
              _field(
                _availableRoomsController,
                'Available Rooms',
                'e.g. 10',
                keyboardType: TextInputType.number,
                validator: _intVal('rooms'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _ratingController,
                      'Rating (0-5)',
                      '4.5',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final r = double.tryParse(v);
                        if (r == null || r < 0 || r > 5) {
                          return '0 – 5';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _field(
                      _totalReviewsController,
                      'Total Reviews',
                      '0',
                      keyboardType: TextInputType.number,
                      validator: _intVal('reviews'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionTitle('Images'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manage images (Max 10 total)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                  Text(
                    '${_existingImageUrls.length + _newSelectedImages.length}/10',
                    style: TextStyle(
                      color: (_existingImageUrls.length + _newSelectedImages.length) >= 10
                          ? Colors.red
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Image Management Section ───────────────────
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Existing Images (Cloudinary)
                      if (_existingImageUrls.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'Current Images:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_existingImageUrls.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _existingImageUrls.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _existingImageUrls[index],
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (_, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeExistingImage(index),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // New Selected Images
                      if (_newSelectedImages.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'New Images to Upload:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_newSelectedImages.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _newSelectedImages.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _newSelectedImages[index],
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeNewImage(index),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // No Images State
                      if (_existingImageUrls.isEmpty && _newSelectedImages.isEmpty) ...[
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No images',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add images to showcase your hostel',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Add Images Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (_existingImageUrls.length + _newSelectedImages.length) >= 10
                              ? null
                              : _showImageSourceActionSheet,
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(
                            (_existingImageUrls.length + _newSelectedImages.length) >= 10
                                ? 'Maximum images reached'
                                : 'Add More Images',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: (_existingImageUrls.length + _newSelectedImages.length) >= 10
                                  ? Colors.grey
                                  : AppTheme.primaryRed,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _sectionTitle('Amenities'),
              const SizedBox(height: 14),
              _amenities.isEmpty
                  ? Text(
                'No amenities added',
                style: TextStyle(color: Colors.grey[600]),
              )
                  : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _amenities.map((a) {
                  return Chip(
                    label: Text(a),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _amenities.remove(a)),
                    backgroundColor: AppTheme.primaryRed.withAlpha(10),
                    labelStyle: const TextStyle(
                      color: AppTheme.primaryRed,
                    ),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amenityController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Swimming Pool',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryRed,
                            width: 2,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (_) => _addAmenity(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addAmenity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _isUploading) ? null : _save,
                  icon: const Icon(
                    Icons.save_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _addAmenity() {
    final a = _amenityController.text.trim();
    if (a.isNotEmpty && !_amenities.contains(a)) {
      setState(() {
        _amenities.add(a);
        _amenityController.clear();
      });
    }
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );

  Widget _field(
      TextEditingController c,
      String label,
      String hint, {
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
        String? Function(String?)? validator,
      }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primaryRed, width: 2),
          ),
        ),
      ),
    ],
  );

  String? Function(String?) _req(String f) =>
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? Function(String?) _numVal(String f) => (v) {
    if (v == null || v.isEmpty) return 'Required';
    if (double.tryParse(v) == null) return 'Invalid number';
    return null;
  };

  String? Function(String?) _intVal(String f) => (v) {
    if (v == null || v.isEmpty) return 'Required';
    if (int.tryParse(v) == null) return 'Whole number only';
    if (int.parse(v) < 0) return 'Cannot be negative';
    return null;
  };
}