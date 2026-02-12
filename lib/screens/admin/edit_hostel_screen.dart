import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
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

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _priceController;
  late final TextEditingController _availableRoomsController;
  late final TextEditingController _ratingController;
  late final TextEditingController _totalReviewsController;
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _amenityController = TextEditingController();

  late List<String> _imageUrls;
  late List<String> _amenities;
  bool _isLoading = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
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
    _imageUrls = List.from(h.images);
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
    _imageUrlController.dispose();
    _amenityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      _snack('Please add at least one image URL', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
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
        images: _imageUrls,
        amenities: _amenities,
        isActive: _isActive,
      );

      await _firestoreService.updateHostel(updated);
      _snack('Hostel updated successfully!');

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Update failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
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
        title: const Text('Edit Hostel'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Saving changes...')
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
                            activeThumbColor: Colors.green,
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
                    const SizedBox(height: 14),
                    _urlRow(
                      controller: _imageUrlController,
                      hint: 'https://example.com/photo.jpg',
                      keyboardType: TextInputType.url,
                      onAdd: () {
                        final url = _imageUrlController.text.trim();
                        if (url.isNotEmpty && !_imageUrls.contains(url)) {
                          setState(() {
                            _imageUrls.add(url);
                            _imageUrlController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _imagePreview(),
                    const SizedBox(height: 24),

                    _sectionTitle('Amenities'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _amenities.map((a) {
                        return Chip(
                          label: Text(a),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _amenities.remove(a)),
                          backgroundColor: AppTheme.primaryRed.withValues(
                            alpha: 0.08,
                          ),
                          labelStyle: const TextStyle(
                            color: AppTheme.primaryRed,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    _urlRow(
                      controller: _amenityController,
                      hint: 'e.g. Parking',
                      onAdd: () {
                        final a = _amenityController.text.trim();
                        if (a.isNotEmpty && !_amenities.contains(a)) {
                          setState(() {
                            _amenities.add(a);
                            _amenityController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _save,
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

  Widget _imagePreview() {
    if (_imageUrls.isEmpty) {
      return Text(
        'No images added',
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
      );
    }
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imageUrls.length,
        itemBuilder: (_, i) => Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: NetworkImage(_imageUrls[i]),
                  fit: BoxFit.cover,
                  onError: (_, _) {},
                ),
                color: Colors.grey[200],
              ),
            ),
            Positioned(
              top: 4,
              right: 12,
              child: GestureDetector(
                onTap: () => setState(() => _imageUrls.removeAt(i)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primaryRed, width: 2),
          ),
        ),
      ),
    ],
  );

  Widget _urlRow({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
    TextInputType keyboardType = TextInputType.text,
  }) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
    return null;
  };
}
