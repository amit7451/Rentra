import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
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

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _priceController = TextEditingController();
  final _availableRoomsController = TextEditingController();
  final _ratingController = TextEditingController();
  final _totalReviewsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _amenityController = TextEditingController();

  final List<String> _imageUrls = [];
  List<String> _amenities = ['WiFi', 'Laundry'];
  bool _isLoading = false;
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    _ratingController.text = '4.5';
    _totalReviewsController.text = '0';
    _availableRoomsController.text = '10';
    _ownerId = FirebaseAuth.instance.currentUser?.uid;
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
    _imageUrlController.dispose();
    _amenityController.dispose();
    super.dispose();
  }

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isNotEmpty && !_imageUrls.contains(url)) {
      setState(() {
        _imageUrls.add(url);
        _imageUrlController.clear();
      });
    }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      _showSnack('Please add at least one image URL', isError: true);
      return;
    }
    if (_ownerId == null) {
      _showSnack('No authenticated user found', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hostel = HostelModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        pricePerNight: double.parse(_priceController.text),
        availableRooms: int.parse(_availableRoomsController.text),
        rating: double.parse(_ratingController.text),
        totalReviews: int.parse(_totalReviewsController.text),
        images: _imageUrls,
        amenities: _amenities,
        ownerId: _ownerId!,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _firestoreService.addHostel(hostel);
      _showSnack('Hostel listed successfully!');
      _resetForm();
    } catch (e) {
      _showSnack('Failed to add hostel: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
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
      _imageUrls.clear();
      _amenities = ['WiFi', 'Laundry'];
    });
    _ratingController.text = '4.5';
    _totalReviewsController.text = '0';
    _availableRoomsController.text = '10';
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
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
      body: _isLoading
          ? const LoadingIndicator(message: 'Submitting hostel details...')
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
                      'Description',
                      'Describe your hostel',
                      maxLines: 4,
                      validator: _required('description'),
                    ),
                    const SizedBox(height: 24),

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
                    _field(
                      _priceController,
                      'Price Per Year (₹)',
                      'e.g. 50000',
                      keyboardType: TextInputType.number,
                      validator: _numericValidator('price'),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _availableRoomsController,
                      'Available Rooms',
                      'e.g. 10',
                      keyboardType: TextInputType.number,
                      validator: _intValidator('available rooms'),
                    ),
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
                    Text(
                      'Add at least one image URL',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _urlInputRow(
                      controller: _imageUrlController,
                      hint: 'https://example.com/image.jpg',
                      onAdd: _addImageUrl,
                      keyboardType: TextInputType.url,
                    ),
                    if (_imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          _imageUrls.length,
                          (i) => Chip(
                            avatar: const Icon(Icons.image_outlined, size: 16),
                            label: Text('Image ${i + 1}'),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () =>
                                setState(() => _imageUrls.removeAt(i)),
                            backgroundColor: AppTheme.primaryRed.withOpacity(
                              0.08,
                            ),
                            labelStyle: const TextStyle(
                              color: AppTheme.primaryRed,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    _sectionTitle('Amenities'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _amenities.map((a) {
                        return Chip(
                          label: Text(a),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _amenities.remove(a)),
                          backgroundColor: AppTheme.primaryRed.withOpacity(
                            0.08,
                          ),
                          labelStyle: const TextStyle(
                            color: AppTheme.primaryRed,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    _urlInputRow(
                      controller: _amenityController,
                      hint: 'e.g. Swimming Pool',
                      onAdd: _addAmenity,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Submit Hostel',
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
                            borderRadius: BorderRadius.circular(12),
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

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.primaryRed,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _urlInputRow({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.primaryRed,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryRed,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Add',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    return null;
  };
}
