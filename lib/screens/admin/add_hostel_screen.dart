import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _priceController = TextEditingController();
  final _flatCapacityController = TextEditingController();
  final _availableRoomsController = TextEditingController();
  final _ratingController = TextEditingController();
  final _totalReviewsController = TextEditingController();
  final _amenityController = TextEditingController();
  final _houseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _placesSearchController = TextEditingController();

  // Multi-seater controllers
  final _price1Controller = TextEditingController();
  final _price2Controller = TextEditingController();
  final _price3Controller = TextEditingController();
  final _rooms1Controller = TextEditingController();
  final _rooms2Controller = TextEditingController();
  final _rooms3Controller = TextEditingController();

  final FocusNode _placesFocusNode = FocusNode();
  final GlobalKey _placesSearchKey = GlobalKey();

  // State Variables
  final List<File> _selectedImages = [];
  final List<String> _amenities = ['WiFi', 'Laundry'];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isCloudinaryReady = false;
  String? _ownerId;
  String _unitType = 'hostel';

  // Maps & Location
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(28.6139, 77.2090);
  LatLng? _pickedLocation;
  String? _googleMapAddress;
  bool _gettingLocation = false;
  bool _isMapFullScreen = false;

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
    final controllers = [
      _nameController,
      _descriptionController,
      _addressController,
      _cityController,
      _stateController,
      _pincodeController,
      _countryController,
      _priceController,
      _flatCapacityController,
      _availableRoomsController,
      _ratingController,
      _totalReviewsController,
      _amenityController,
      _houseNoController,
      _streetController,
      _placesSearchController,
      _price1Controller,
      _price2Controller,
      _price3Controller,
      _rooms1Controller,
      _rooms2Controller,
      _rooms3Controller,
    ];
    for (var c in controllers) {
      c.dispose();
    }
    _placesFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────────────

  Future<void> _checkCloudinaryStatus() async {
    _isCloudinaryReady = CloudinaryService.isInitialized;
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
        if (permission == LocationPermission.denied) throw 'Permission denied';
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Permission permanently denied';
      }

      final pos = await Geolocator.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pickedLocation = latLng;
        _initialPosition = latLng;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      await _reverseGeocode(latLng);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
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
          _placesSearchController.text = address;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImages({bool camera = false}) async {
    try {
      final file = camera
          ? await _picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 1200,
              imageQuality: 85,
            )
          : await _picker.pickMultiImage(maxWidth: 1200, imageQuality: 85);

      if (file == null) return;
      final List<XFile> incoming = file is List<XFile> ? file : [file as XFile];

      if (_selectedImages.length + incoming.length > 10) {
        _showSnack('Maximum 10 images allowed', isError: true);
        return;
      }
      setState(() => _selectedImages.addAll(incoming.map((f) => File(f.path))));
    } catch (_) {
      _showSnack('Failed to pick images', isError: true);
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
    if (_selectedImages.isEmpty) {
      return _showSnack('Please select at least one image', isError: true);
    }
    if (_ownerId == null) {
      return _showSnack('No authenticated user found', isError: true);
    }

    setState(() => _isUploading = true);
    try {
      final urls = await _cloudinaryService.uploadMultipleImages(
        _selectedImages,
      );
      if (urls.isEmpty) throw 'Failed to upload images';

      setState(() => _isLoading = true);
      final p1 = double.tryParse(_price1Controller.text) ?? 0;
      final p2 = double.tryParse(_price2Controller.text) ?? 0;
      final p3 = double.tryParse(_price3Controller.text) ?? 0;
      final r1 = int.tryParse(_rooms1Controller.text) ?? 0;
      final r2 = int.tryParse(_rooms2Controller.text) ?? 0;
      final r3 = int.tryParse(_rooms3Controller.text) ?? 0;

      final hostel = HostelModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        country: _countryController.text.trim(),
        rentPrice: _unitType == 'flat'
            ? double.tryParse(_priceController.text) ?? 0
            : 0,
        latitude: _pickedLocation?.latitude,
        longitude: _pickedLocation?.longitude,
        googleMapAddress: _googleMapAddress,
        price1Seater: p1,
        price2Seater: p2,
        price3Seater: p3,
        rooms1Seater: r1,
        rooms2Seater: r2,
        rooms3Seater: r3,
        unitType: _unitType,
        flatCapacity: int.tryParse(_flatCapacityController.text),
        rentPeriod: _unitType == 'flat' ? 'monthly' : 'yearly',
        availableRooms: _unitType == 'flat' ? 1 : (r1 + r2 + r3),
        rating: double.tryParse(_ratingController.text) ?? 4.5,
        totalReviews: int.tryParse(_totalReviewsController.text) ?? 0,
        images: urls,
        amenities: _amenities,
        ownerId: _ownerId!,
        createdAt: DateTime.now(),
        isActive: true,
      );

      final hostelId = await _firestoreService.addHostel(hostel);

      // Notify users about the new property (Broadcast)
      _firestoreService.broadcastNewPropertyNotification(
        hostel: hostel.copyWith(id: hostelId),
        // maxDistanceKm: 10.0, // Example for future range filtering
      );

      _showSnack('Hostel listed successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = _isLoading = false);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isUploading) {
      return LoadingIndicator(
        message: _isUploading ? 'Uploading images...' : 'Saving property...',
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                    _sectionHeader('Basic Information'),
                    _field(
                      _nameController,
                      'Hostel Name',
                      'e.g. Royal Residency',
                      validator: _valReq('name'),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _descriptionController,
                      'Description (Optional)',
                      'Rules, details, etc.',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    _buildPropertyTypeSelector(),
                    const SizedBox(height: 24),

                    _sectionHeader('Location Details'),
                    _buildLocationPicker(),
                    const SizedBox(height: 16),
                    _buildSpecificLocationDetails(),
                    const SizedBox(height: 16),
                    _field(
                      _addressController,
                      'Full Address',
                      'Search above or enter manually',
                      validator: _valReq('address'),
                    ),
                    const SizedBox(height: 16),
                    _buildAddressRow(
                      _cityController,
                      'City',
                      _stateController,
                      'State',
                    ),
                    const SizedBox(height: 16),
                    _buildAddressRow(
                      _pincodeController,
                      'Pincode',
                      _countryController,
                      'Country',
                      isNum: true,
                    ),
                    const SizedBox(height: 32),

                    _sectionHeader('Pricing & Capacity'),
                    if (_unitType == 'flat') ...[
                      _field(
                        _priceController,
                        'Monthly Rent (₹)',
                        'e.g. 12000',
                        keyboardType: TextInputType.number,
                        validator: _valInt('rent'),
                      ),
                      const SizedBox(height: 16),
                      _field(
                        _flatCapacityController,
                        'Total Capacity (Persons)',
                        'e.g. 3',
                        keyboardType: TextInputType.number,
                        validator: _valInt('capacity'),
                      ),
                    ] else
                      _buildHostelPricingGrid(),
                    const SizedBox(height: 24),

                    _buildInitialStatsSection(),
                    const SizedBox(height: 32),

                    _sectionHeader('Media & Amenities'),
                    _buildImageGallery(),
                    const SizedBox(height: 24),
                    _buildAmenitiesSection(),
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
      scrolledUnderElevation: 4,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.grey[50],
      title: const Text(
        'Add Hostel',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(color: Colors.grey[50]),
      ),
    );
  }

  Widget _buildPropertyTypeSelector() {
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
          decoration: _inputDecoration(''),
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
                  markers: _pickedLocation == null
                      ? {}
                      : {
                          Marker(
                            markerId: const MarkerId('picked'),
                            position: _pickedLocation!,
                            draggable: true,
                            onDragEnd: (p) =>
                                setState(() => _pickedLocation = p),
                          ),
                        },
                  onTap: (p) {
                    setState(() => _pickedLocation = p);
                    _reverseGeocode(p);
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: FloatingActionButton.small(
                  heroTag: 'map_toggle',
                  backgroundColor: Colors.white,
                  onPressed: () =>
                      setState(() => _isMapFullScreen = !_isMapFullScreen),
                  child: Icon(
                    _isMapFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificLocationDetails() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withAlpha(15)),
      ),
      child: ExpansionTile(
        leading: const Icon(
          Icons.home_work_outlined,
          color: Colors.blue,
          size: 20,
        ),
        title: const Text(
          "Unit Specifics (House/Street)",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _field(_houseNoController, 'House No / Flat No', 'e.g. 102'),
                const SizedBox(height: 12),
                _field(
                  _streetController,
                  'Street / Landmark',
                  'e.g. Near Park',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostelPricingGrid() {
    return Column(
      children: [
        _seaterRow('1-Seater', _price1Controller, _rooms1Controller),
        const SizedBox(height: 16),
        _seaterRow('2-Seater', _price2Controller, _rooms2Controller),
        const SizedBox(height: 16),
        _seaterRow('3-Seater', _price3Controller, _rooms3Controller),
      ],
    );
  }

  Widget _seaterRow(
    String label,
    TextEditingController price,
    TextEditingController count,
  ) {
    return Row(
      children: [
        Expanded(
          child: _field(
            price,
            '$label Price',
            '₹ Rent',
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _field(
            count,
            '$label Count',
            'How many?',
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Trust Signals (Initial)'),
        Row(
          children: [
            Expanded(
              child: _field(
                _ratingController,
                'Initial Rating',
                '0-5',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _field(
                _totalReviewsController,
                'Review Count',
                'Initial reviews',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
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
              'Property Photos',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              '${_selectedImages.length}/10',
              style: TextStyle(
                color: _selectedImages.length >= 10 ? Colors.red : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (_selectedImages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImages[i],
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedImages.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectedImages.length >= 10
                      ? null
                      : _showImageSourcePicker,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Photos'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
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
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('From Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImages(camera: true);
              },
            ),
            const SizedBox(height: 16),
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
          'Key Amenities',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                  deleteIcon: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppTheme.primaryRed,
                  ),
                  onDeleted: () => setState(() => _amenities.remove(a)),
                  backgroundColor: AppTheme.primaryRed.withAlpha(10),
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _amenityController,
                decoration: _inputDecoration('e.g. AC, Lift'),
                onFieldSubmitted: (_) => _addAmenity(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addAmenity,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isLoading || _isUploading || _selectedImages.isEmpty)
            ? null
            : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryRed,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: AppTheme.primaryRed.withAlpha(50),
        ),
        child: const Text(
          'Submit Listing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: _inputDecoration(hint),
        ),
      ],
    );
  }

  Widget _buildAddressRow(
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
            c1,
            l1,
            l1,
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            validator: _valReq(l1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _field(c2, l2, l2, validator: _valReq(l2))),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: prefix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      );

  String? Function(String?) _valReq(String name) =>
      (v) => (v == null || v.trim().isEmpty) ? 'Enter $name' : null;

  String? Function(String?) _valInt(String name) => (v) {
    if (v == null || v.isEmpty) return 'Enter $name';
    if (int.tryParse(v) == null) return 'Numbers only';
    return null;
  };
}
