import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';

class AddHostelScreen extends StatefulWidget {
  const AddHostelScreen({super.key});

  @override
  State<AddHostelScreen> createState() => _AddHostelScreenState();
}

class _AddHostelScreenState extends State<AddHostelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _cloudinaryService = CloudinaryService.instance;
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _priceController = TextEditingController();
  final _price1Controller = TextEditingController();
  final _price2Controller = TextEditingController();
  final _price3Controller = TextEditingController();
  final _rooms1Controller = TextEditingController();
  final _rooms2Controller = TextEditingController();
  final _rooms3Controller = TextEditingController();
  final _flatCapacityController = TextEditingController();
  final _availableRoomsController = TextEditingController();
  final _ratingController = TextEditingController();
  final _totalReviewsController = TextEditingController();
  final _amenityController = TextEditingController();

  final List<File> _selectedImages = [];
  List<String> _amenities = ['WiFi', 'Laundry'];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isCloudinaryReady = false;
  String? _ownerId;
  String _unitType = 'hostel'; // 'hostel' or 'flat'

  @override
  void initState() {
    super.initState();
    _ratingController.text = '4.5';
    _totalReviewsController.text = '0';
    _availableRoomsController.text = '10';
    _ownerId = FirebaseAuth.instance.currentUser?.uid;
    _checkCloudinaryStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _priceController.dispose();
    _price1Controller.dispose();
    _price2Controller.dispose();
    _price3Controller.dispose();
    _rooms1Controller.dispose();
    _rooms2Controller.dispose();
    _rooms3Controller.dispose();
    _flatCapacityController.dispose();
    _availableRoomsController.dispose();
    _ratingController.dispose();
    _totalReviewsController.dispose();
    _amenityController.dispose();
    super.dispose();
  }

  Future<void> _checkCloudinaryStatus() async {
    if (!mounted) {
      return;
    }
    setState(() => _isCloudinaryReady = CloudinaryService.isInitialized);

    if (!_isCloudinaryReady) {
      try {
        await CloudinaryService.initialize();
        if (mounted) setState(() => _isCloudinaryReady = true);
      } catch (e) {
        if (mounted) _showSnack('Upload service not available', isError: true);
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        if (pickedFiles.length + _selectedImages.length > 10) {
          _showSnack('Maximum 10 images allowed', isError: true);
          return;
        }
        setState(() {
          _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
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
        if (_selectedImages.length >= 10) {
          _showSnack('Maximum 10 images allowed', isError: true);
          return;
        }
        setState(() => _selectedImages.add(File(pickedFile.path)));
      }
    } catch (e) {
      _showSnack('Failed to take photo', isError: true);
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      _showSnack('Please select at least one image', isError: true);
      return;
    }

    if (_ownerId == null) {
      _showSnack('No authenticated user found', isError: true);
      return;
    }

    if (!_isCloudinaryReady) {
      await _checkCloudinaryStatus();
      if (!_isCloudinaryReady) {
        _showSnack('Upload service not available', isError: true);
        return;
      }
    }

    setState(() => _isUploading = true);

    try {
      // Upload all images to Cloudinary
      final uploadedUrls = await _cloudinaryService.uploadMultipleImages(
        _selectedImages,
      );

      if (uploadedUrls.isEmpty) {
        throw Exception('Failed to upload images');
      }

      setState(() => _isLoading = true);

      // prepare fields depending on unit type
      double parsedPrice = 0.0;
      int availableRooms = 0;
      double p1 = 0.0, p2 = 0.0, p3 = 0.0;
      int r1 = 0, r2 = 0, r3 = 0;
      int? flatCap;

      if (_unitType == 'flat') {
        // Use tryParse to avoid crashes if the field is somehow empty
        parsedPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
        flatCap = int.tryParse(_flatCapacityController.text.trim()) ?? 1;
        availableRooms = 1;
      } else {
        // Hostel / PG Logic
        p1 = double.tryParse(_price1Controller.text.trim()) ?? 0.0;
        p2 = double.tryParse(_price2Controller.text.trim()) ?? 0.0;
        p3 = double.tryParse(_price3Controller.text.trim()) ?? 0.0;

        r1 = int.tryParse(_rooms1Controller.text.trim()) ?? 0;
        r2 = int.tryParse(_rooms2Controller.text.trim()) ?? 0;
        r3 = int.tryParse(_rooms3Controller.text.trim()) ?? 0;

        availableRooms = r1 + r2 + r3;
      }

      final hostel = HostelModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        rentPrice: parsedPrice,
        price1Seater: p1,
        price2Seater: p2,
        price3Seater: p3,
        rooms1Seater: r1,
        rooms2Seater: r2,
        rooms3Seater: r3,
        flatCapacity: flatCap,
        unitType: _unitType,
        rentPeriod: _unitType == 'flat' ? 'monthly' : 'yearly',
        availableRooms: availableRooms,
        rating: double.tryParse(_ratingController.text) ?? 4.5,
        totalReviews: int.tryParse(_totalReviewsController.text) ?? 0,
        images: uploadedUrls,
        amenities: _amenities,
        ownerId: _ownerId!,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _firestoreService.addHostel(hostel);

      if (mounted) {
        _showSnack('Hostel listed successfully!');
        _resetForm();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'Failed: ${e.toString().replaceAll('Exception:', '')}',
          isError: true,
        );
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

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _nameController.clear();
      _descriptionController.clear();
      _addressController.clear();
      _cityController.clear();
      _countryController.clear();
      _priceController.clear();
      _selectedImages.clear();
      _amenities = ['WiFi', 'Laundry'];
    });
    _ratingController.text = '4.5';
    _totalReviewsController.text = '0';
    _availableRoomsController.text = '10';
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Hostel'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading || _isUploading
          ? LoadingIndicator(
              message: _isUploading
                  ? 'Submitting hostel details...'
                  : 'Submitting hostel details...',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Basic Information'),
                    const SizedBox(height: 16),
                    _field(
                      _nameController,
                      'Hostel Name',
                      'e.g. Sharma Flat',
                      validator: _required('hostel name'),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _descriptionController,
                      'Description (Optional)',
                      'List amenities, rules, or details',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),

                    // Unit type selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Property Type',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _unitType,
                          items: const [
                            DropdownMenuItem(
                              value: 'hostel',
                              child: Text('Hostel / PG'),
                            ),
                            DropdownMenuItem(
                              value: 'flat',
                              child: Text('Flat'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) {
                              return;
                            }
                            setState(() {
                              _unitType = v;
                            });
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _sectionTitle('Location'),
                    const SizedBox(height: 16),
                    _field(
                      _addressController,
                      'Full Address',
                      'Street address',
                      validator: _required('address'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _cityController,
                            'City',
                            'City',
                            validator: _required('city'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _field(
                            _countryController,
                            'Country',
                            'Country',
                            validator: _required('country'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle('Pricing & Availability'),
                    const SizedBox(height: 16),
                    if (_unitType == 'flat') ...[
                      _field(
                        _priceController,
                        'Price Per Month (₹)',
                        'e.g. 5000',
                        keyboardType: TextInputType.number,
                        validator: _numericValidator('price'),
                      ),
                      const SizedBox(height: 16),
                      _field(
                        _flatCapacityController,
                        'Capacity (persons)',
                        'e.g. 2',
                        keyboardType: TextInputType.number,
                        validator: _intValidator('capacity'),
                      ),
                    ] else ...[
                      // Hostel / PG: pricing and counts per seater
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _price1Controller,
                              '1-seater Price (Optional)',
                              'e.g. 8000',
                              keyboardType: TextInputType.number,
                              validator: _optionalNumericValidator(
                                '1-seater price',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              _rooms1Controller,
                              '1-seater Count (Optional)',
                              'e.g. 5',
                              keyboardType: TextInputType.number,
                              validator: _optionalIntValidator(
                                '1-seater count',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _price2Controller,
                              '2-seater Price (Optional)',
                              'e.g. 6000',
                              keyboardType: TextInputType.number,
                              validator: _optionalNumericValidator(
                                '2-seater price',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              _rooms2Controller,
                              '2-seater Count (Optional)',
                              'e.g. 10',
                              keyboardType: TextInputType.number,
                              validator: _optionalIntValidator(
                                '2-seater count',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _price3Controller,
                              '3-seater Price (Optional)',
                              'e.g. 4000',
                              keyboardType: TextInputType.number,
                              validator: _optionalNumericValidator(
                                '3-seater price',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              _rooms3Controller,
                              '3-seater Count (Optional)',
                              'e.g. 8',
                              keyboardType: TextInputType.number,
                              validator: _optionalIntValidator(
                                '3-seater count',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    _sectionTitle('Ratings & Feedback (Initial)'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _ratingController,
                            'Rating (0-5)',
                            'e.g. 4.5',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final r = double.tryParse(v);
                              if (r == null || r < 0 || r > 5) {
                                return 'Must be 0-5';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _field(
                            _totalReviewsController,
                            'Total Reviews',
                            'e.g. 0',
                            keyboardType: TextInputType.number,
                            validator: _intValidator('total reviews'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle('Hostel Images'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select images (Max 10 images)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${_selectedImages.length}/10',
                          style: TextStyle(
                            color: _selectedImages.length >= 10
                                ? Colors.red
                                : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

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
                            if (_selectedImages.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text(
                                    'Selected Images:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_selectedImages.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryRed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 100,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedImages.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            _selectedImages[index],
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                Container(
                                                  width: 100,
                                                  height: 100,
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
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

                            if (_selectedImages.isEmpty) ...[
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
                                      'No images selected',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Images will be uploaded when you submit',
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

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _selectedImages.length >= 10
                                    ? null
                                    : _showImageSourceActionSheet,
                                icon: const Icon(Icons.add_a_photo),
                                label: Text(
                                  _selectedImages.length >= 10
                                      ? 'Maximum images reached'
                                      : 'Add Images',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(
                                    color: _selectedImages.length >= 10
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
                    const SizedBox(height: 12),
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
                                onDeleted: () =>
                                    setState(() => _amenities.remove(a)),
                                backgroundColor: AppTheme.primaryRed.withAlpha(
                                  10,
                                ),
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
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
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

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isLoading ||
                                _isUploading ||
                                _selectedImages.isEmpty)
                            ? null
                            : _submit,
                        icon: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.white,
                        ),
                        label: Text(
                          _selectedImages.isEmpty
                              ? 'Add Images First'
                              : 'Submit Hostel',
                          style: const TextStyle(
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
                          disabledBackgroundColor: Colors.grey[400],
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

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            contentPadding: const EdgeInsets.all(14),
            filled: readOnly,
            fillColor: readOnly ? Colors.grey[100] : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  String? Function(String?) _required(String fieldName) =>
      (v) => (v == null || v.trim().isEmpty) ? 'Please enter $fieldName' : null;

  String? Function(String?) _numericValidator(String fieldName) => (v) {
    if (v == null || v.isEmpty) return 'Please enter $fieldName';
    if (double.tryParse(v) == null) return 'Enter a valid number';
    return null;
  };

  String? Function(String?) _intValidator(String fieldName) => (v) {
    if (v == null || v.isEmpty) return 'Please enter $fieldName';
    if (int.tryParse(v) == null) return 'Enter a whole number';
    if (int.parse(v) < 0) return 'Cannot be negative';
    return null;
  };

  String? Function(String?) _optionalNumericValidator(String fieldName) => (v) {
    if (v == null || v.isEmpty) return null;
    if (double.tryParse(v) == null) return 'Enter a valid number';
    return null;
  };

  String? Function(String?) _optionalIntValidator(String fieldName) => (v) {
    if (v == null || v.isEmpty) return null;
    if (int.tryParse(v) == null) return 'Enter a whole number';
    if (int.parse(v) < 0) return 'Cannot be negative';
    return null;
  };
}
