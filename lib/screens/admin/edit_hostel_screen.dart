import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/hostel_model.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/glass_card.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _countryController;
  late final TextEditingController _priceController;
  late final TextEditingController _availableRoomsController;
  late final TextEditingController _ratingController;
  late final TextEditingController _totalReviewsController;
  final TextEditingController _amenityController = TextEditingController();
  late final TextEditingController _placesSearchController;

  // Multi-seater controllers
  late final TextEditingController _price1Controller;
  late final TextEditingController _price2Controller;
  late final TextEditingController _price3Controller;
  late final TextEditingController _rooms1Controller;
  late final TextEditingController _rooms2Controller;
  late final TextEditingController _rooms3Controller;
  late final TextEditingController _flatCapacityController;

  final FocusNode _placesFocusNode = FocusNode();
  final GlobalKey _placesSearchKey = GlobalKey();

  // Map state
  GoogleMapController? _mapController;
  LatLng? _pickedLocation;
  late LatLng _initialPosition;
  String? _googleMapAddress;
  bool _gettingLocation = false;
  bool _isMapFullScreen = false;

  late List<String> _existingImageUrls;
  final List<File> _newSelectedImages = [];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isCloudinaryReady = false;
  late List<String> _amenities;
  late bool _isActive;
  late String _unitType;

  @override
  void initState() {
    super.initState();
    _checkCloudinaryStatus();

    final h = widget.hostel;
    _nameController = TextEditingController(text: h.name);
    _descriptionController = TextEditingController(text: h.description);
    _addressController = TextEditingController(text: h.address);
    _cityController = TextEditingController(text: h.city);
    _stateController = TextEditingController(text: h.state ?? "");
    _pincodeController = TextEditingController(text: h.pincode ?? "");
    _countryController = TextEditingController(text: h.country);
    _priceController = TextEditingController(text: h.rentPrice.toString());
    _availableRoomsController = TextEditingController(
      text: h.availableRooms.toString(),
    );
    _price1Controller = TextEditingController(
      text: h.price1Seater?.toString() ?? '',
    );
    _price2Controller = TextEditingController(
      text: h.price2Seater?.toString() ?? '',
    );
    _price3Controller = TextEditingController(
      text: h.price3Seater?.toString() ?? '',
    );
    _rooms1Controller = TextEditingController(text: h.rooms1Seater.toString());
    _rooms2Controller = TextEditingController(text: h.rooms2Seater.toString());
    _rooms3Controller = TextEditingController(text: h.rooms3Seater.toString());
    _flatCapacityController = TextEditingController(
      text: h.flatCapacity?.toString() ?? '',
    );
    _ratingController = TextEditingController(text: h.rating.toString());
    _totalReviewsController = TextEditingController(
      text: h.totalReviews.toString(),
    );
    _placesSearchController = TextEditingController(
      text: h.googleMapAddress ?? h.address,
    );

    _existingImageUrls = List.from(h.images);
    _amenities = List.from(h.amenities);
    _isActive = h.isActive;
    _unitType = h.unitType;

    // Set initial position
    if (h.latitude != null && h.longitude != null) {
      _pickedLocation = LatLng(h.latitude!, h.longitude!);
      _initialPosition = LatLng(h.latitude!, h.longitude!);
    } else {
      _initialPosition = const LatLng(28.6139, 77.2090); // Default Delhi
    }
    _googleMapAddress = h.googleMapAddress;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();
    _priceController.dispose();
    _price1Controller.dispose();
    _price2Controller.dispose();
    _price3Controller.dispose();
    _rooms1Controller.dispose();
    _rooms2Controller.dispose();
    _rooms3Controller.dispose();
    _availableRoomsController.dispose();
    _ratingController.dispose();
    _totalReviewsController.dispose();
    _amenityController.dispose();
    _flatCapacityController.dispose();
    _placesSearchController.dispose();
    _placesFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── HELPER METHODS ────────────────────────────────────────────────────────

  Future<void> _checkCloudinaryStatus() async {
    setState(() {
      _isCloudinaryReady = CloudinaryService.isInitialized;
    });
    if (!_isCloudinaryReady) {
      try {
        await CloudinaryService.initialize();
        if (mounted) setState(() => _isCloudinaryReady = true);
      } catch (_) {}
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition();
        final latLng = LatLng(pos.latitude, pos.longitude);
        _pickedLocation = latLng;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        await _reverseGeocode(latLng);
      }
    } catch (_) {}
    setState(() => _gettingLocation = false);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final marks = await geo.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (marks.isNotEmpty) {
        final p = marks.first;
        final address =
            "${p.street}, ${p.subLocality}, ${p.locality}, "
            "${p.administrativeArea} ${p.postalCode}";
        setState(() {
          _googleMapAddress = address;
          _cityController.text = p.locality ?? '';
          _stateController.text = p.administrativeArea ?? '';
          _pincodeController.text = p.postalCode ?? '';
          _countryController.text = p.country ?? '';
          _addressController.text = address;
          _placesSearchController.value = TextEditingValue(
            text: address,
            selection: TextSelection.collapsed(offset: address.length),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImages({bool camera = false}) async {
    try {
      final source = camera ? ImageSource.camera : ImageSource.gallery;
      if (camera) {
        final XFile? file = await _picker.pickImage(
          source: source,
          imageQuality: 70,
        );
        if (file != null) {
          setState(() {
            _newSelectedImages.add(File(file.path));
          });
        }
      } else {
        final List<XFile> files = await _picker.pickMultiImage(
          imageQuality: 70,
        );
        if (files.isNotEmpty) {
          setState(() {
            _newSelectedImages.addAll(files.map((f) => File(f.path)));
          });
        }
      }
    } catch (_) {}
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImageUrls.isEmpty && _newSelectedImages.isEmpty) {
      _showSnack('Please add at least one image', isError: true);
      return;
    }
    if (_pickedLocation == null) {
      _showSnack('Please select location on map', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    try {
      List<String> allImages = [..._existingImageUrls];
      if (_newSelectedImages.isNotEmpty) {
        final urls = await _cloudinaryService.uploadMultipleImages(
          _newSelectedImages,
        );
        allImages.addAll(urls);
      }

      setState(() {
        _isUploading = false;
        _isLoading = true;
      });

      final updated = widget.hostel.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        country: _countryController.text.trim(),
        latitude: _pickedLocation!.latitude,
        longitude: _pickedLocation!.longitude,
        googleMapAddress: _googleMapAddress,
        unitType: _unitType,
        rentPrice: double.tryParse(_priceController.text) ?? 0,
        price1Seater: double.tryParse(_price1Controller.text) ?? 0,
        price2Seater: double.tryParse(_price2Controller.text) ?? 0,
        price3Seater: double.tryParse(_price3Controller.text) ?? 0,
        rooms1Seater: int.tryParse(_rooms1Controller.text) ?? 0,
        rooms2Seater: int.tryParse(_rooms2Controller.text) ?? 0,
        rooms3Seater: int.tryParse(_rooms3Controller.text) ?? 0,
        flatCapacity: int.tryParse(_flatCapacityController.text) ?? 1,
        availableRooms: _unitType == 'flat'
            ? (int.tryParse(_availableRoomsController.text) ?? 1)
            : (int.tryParse(_rooms1Controller.text) ?? 0) +
                  (int.tryParse(_rooms2Controller.text) ?? 0) +
                  (int.tryParse(_rooms3Controller.text) ?? 0),
        rating: double.tryParse(_ratingController.text) ?? 0.0,
        totalReviews: int.tryParse(_totalReviewsController.text) ?? 0,
        images: allImages,
        amenities: _amenities,
        isActive: _isActive,
      );

      await _firestoreService.updateHostel(updated);
      if (mounted) {
        Navigator.pop(context, true);
        _showSnack('Property updated successfully!');
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.primaryTeal : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── BUILD UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isUploading) {
      return LoadingIndicator(
        message: _isUploading ? 'Uploading images...' : 'Saving changes...',
      );
    }

    return Scaffold(      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildActiveToggle(context),
                          const SizedBox(height: 24),
                          _sectionHeader(context, 'Basic Information'),
                          _field(
                            context,
                            _nameController,
                            'Hostel Name',
                            'e.g. Royal Residency',
                            validator: _valReq('name'),
                          ),
                          const SizedBox(height: 16),
                          _field(
                            context,
                            _descriptionController,
                            'Description (Optional)',
                            'Rules, details, etc.',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),
                          _buildPropertyTypeSelector(context),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Location Details'),
                          _buildLocationPicker(),
                          const SizedBox(height: 16),
                          _field(
                            context,
                            _addressController,
                            'Full Address',
                            'Search above or enter manually',
                            validator: _valReq('address'),
                          ),
                          const SizedBox(height: 16),
                          _buildAddressRow(
                            context,
                            _cityController,
                            'City',
                            _stateController,
                            'State',
                          ),
                          const SizedBox(height: 16),
                          _buildAddressRow(
                            context,
                            _pincodeController,
                            'Pincode',
                            _countryController,
                            'Country',
                            isNum: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Pricing & Capacity'),
                          if (_unitType == 'flat') ...[
                            _field(
                              context,
                              _priceController,
                              'Monthly Rent (₹)',
                              'e.g. 12000',
                              keyboardType: TextInputType.number,
                              validator: _valInt('rent'),
                            ),
                            const SizedBox(height: 16),
                            _field(
                              context,
                              _availableRoomsController,
                              'Available Rooms',
                              'e.g. 1',
                              keyboardType: TextInputType.number,
                              validator: _valInt('rooms'),
                            ),
                            const SizedBox(height: 16),
                            _field(
                              context,
                              _flatCapacityController,
                              'Total Capacity (Persons)',
                              'e.g. 3',
                              keyboardType: TextInputType.number,
                              validator: _valInt('capacity'),
                            ),
                          ] else
                            _buildHostelPricingGrid(context),
                          const SizedBox(height: 32),
                          _sectionHeader(context, 'Ratings & Stats'),
                          _buildStatsGrid(context),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Media & Amenities'),
                          _buildImageGallery(),
                          const SizedBox(height: 24),
                          _buildAmenitiesSection(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    _buildSubmitButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 4,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2F31), Color(0xFF184A4C)],
          ),
        ),
      ),
      title: const Text(
        'Edit Hostel',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildActiveToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isActive
            ? Colors.green.withAlpha(15)
            : Colors.grey.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isActive
              ? Colors.green.withAlpha(30)
              : Colors.grey.withAlpha(30),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
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
                  _isActive ? 'Visible to everyone' : 'Hidden from search',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey),
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
    );
  }

  Widget _buildPropertyTypeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Property Type',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _unitType,
          items: const [
            DropdownMenuItem(value: 'hostel', child: Text('Hostel / PG')),
            DropdownMenuItem(value: 'flat', child: Text('Private Flat')),
          ],
          onChanged: (v) => setState(() => _unitType = v!),
          decoration: _inputDecoration(context, ''),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          dropdownColor: Theme.of(context).cardColor,
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      children: [
        KeyedSubtree(
          key: _placesSearchKey,
          child: GooglePlaceAutoCompleteTextField(
            textEditingController: _placesSearchController,
            googleAPIKey: dotenv.get('GOOGLE_MAPS_API_KEY'),
            focusNode: _placesFocusNode,
            inputDecoration: InputDecoration(
              hintText: 'Search location...',
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.blue,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            debounceTime: 600,
            countries: const ["in"],
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: (p) {
              if (p.lat != null && p.lng != null) {
                final pos = LatLng(double.parse(p.lat!), double.parse(p.lng!));
                final desc = p.description ?? "";
                setState(() {
                  _pickedLocation = pos;
                  _googleMapAddress = desc;
                  _addressController.text = desc;
                  _placesSearchController.value = TextEditingValue(
                    text: desc,
                    selection: TextSelection.collapsed(offset: desc.length),
                  );
                });
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(pos, 16),
                );
              }
            },
            itemClick: (p) {
              _placesFocusNode.requestFocus();
            },
            boxDecoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _gettingLocation ? null : _getCurrentLocation,
            icon: _gettingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                : const Icon(Icons.my_location, color: Colors.blue, size: 18),
            label: const Text(
              'Use Current Location',
              style: TextStyle(color: Colors.blue),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withAlpha(20),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isMapFullScreen
              ? MediaQuery.of(context).size.height * 0.6
              : 280,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 12,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  onTap: (pos) {
                    setState(() => _pickedLocation = pos);
                    _reverseGeocode(pos);
                  },
                  markers: _pickedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('picked'),
                            position: _pickedLocation!,
                            draggable: true,
                            onDragEnd: (pos) {
                              setState(() => _pickedLocation = pos);
                              _reverseGeocode(pos);
                            },
                          ),
                        }
                      : {},
                  myLocationButtonEnabled: false,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: FloatingActionButton.small(
                  onPressed: () =>
                      setState(() => _isMapFullScreen = !_isMapFullScreen),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: Icon(
                    _isMapFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHostelPricingGrid(BuildContext context) {
    return Column(
      children: [
        _seaterRow(context, '1-Seater', _price1Controller, _rooms1Controller),
        const SizedBox(height: 12),
        _seaterRow(context, '2-Seater', _price2Controller, _rooms2Controller),
        const SizedBox(height: 12),
        _seaterRow(context, '3-Seater', _price3Controller, _rooms3Controller),
      ],
    );
  }

  Widget _seaterRow(
    BuildContext context,
    String label,
    TextEditingController price,
    TextEditingController count,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _field(
            context,
            price,
            '$label Price',
            '₹ 0',
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: _field(
            context,
            count,
            'Rooms',
            '0',
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _field(
            context,
            _ratingController,
            'Rating (0-5)',
            '4.5',
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _field(
            context,
            _totalReviewsController,
            'Total Reviews',
            '10',
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Photos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${_existingImageUrls.length + _newSelectedImages.length}/10',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add button
              GestureDetector(
                onTap:
                    (_existingImageUrls.length + _newSelectedImages.length < 10)
                    ? () => _showImageSourcePicker()
                    : null,
                child: Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF14B8A6),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    color: Color(0xFF14B8A6),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Existing Images
              ...List.generate(_existingImageUrls.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _existingImageUrls[i],
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _existingImageUrls.removeAt(i)),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black.withAlpha(100),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // New Images
              ...List.generate(_newSelectedImages.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _newSelectedImages[i],
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _newSelectedImages.removeAt(i)),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primaryTeal.withAlpha(
                              200,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImages(camera: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amenities',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _amenities
              .map(
                (a) => Chip(
                  label: Text(
                    a,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : AppTheme.primaryTeal,
                    ),
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 14,
                    color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white70 
                          : AppTheme.primaryTeal,
                  ),
                  onDeleted: () => setState(() => _amenities.remove(a)),
                  backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  side: BorderSide(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amenityController,
                decoration: _inputDecoration(context, 'Add amenity (e.g. WiFi)'),
                onSubmitted: (_) => _addAmenity(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addAmenity,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Save Changes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
        letterSpacing: -0.5,
      ),
    ),
  );

  Widget _field(
    BuildContext context,
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          cursorColor: AppTheme.getPriceColor(context),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: _inputDecoration(context, hint),
        ),
      ],
    );
  }

  Widget _buildAddressRow(
    BuildContext context,
    TextEditingController c1,
    String l1,
    TextEditingController c2,
    String l2, {
    bool isNum = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: _field(
            context,
            c1,
            l1,
            l1,
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            validator: _valReq(l1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _field(context, c2, l2, l2, validator: _valReq(l2))),
      ],
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint, {Widget? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.grey, fontSize: 14),
        prefixIcon: prefix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
         ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 2.0),
        ),
        filled: false,
      );

  String? Function(String?) _valReq(String name) =>
      (v) => (v == null || v.isEmpty) ? 'Enter $name' : null;
  String? Function(String?) _valInt(String name) =>
      (v) => (v == null || int.tryParse(v) == null) ? 'Invalid $name' : null;
}
