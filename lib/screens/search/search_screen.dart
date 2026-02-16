import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import '../home/hotel_card.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng
import 'package:geolocator/geolocator.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _firestoreService = FirestoreService();

  String _searchQuery = '';
  String _selectedUnitType = 'all'; // 'all', 'hostel', 'flat'
  String _sortBy =
      'rating_desc'; // 'rating_desc', 'price_asc', 'price_desc', 'distance'
  bool _isFiltering = false;

  // Location Filter
  LatLng? _filterLocation;
  double _filterRadius = 3.0; // Default to 3km as requested for location search
  final _locationController = TextEditingController();
  Position? _currentPosition;
  String? _lastSelectedPlace;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // If the text changes and it's NOT what we just selected, it means user is typing manually.
    // We should switch back to text search mode (unless they are refining usage, but simple is better).
    if (_lastSelectedPlace != null &&
        _searchController.text != _lastSelectedPlace) {
      setState(() {
        _lastSelectedPlace = null;
        _filterLocation = null; // Clear strict location filter if typing
        _searchQuery = _searchController.text;
      });
    } else {
      setState(() {
        _searchQuery = _searchController.text;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _currentPosition = pos);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose(); // Dispose the location controller
    super.dispose();
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters & Sorting',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Unit Type Filter
                    const Text(
                      'Unit Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _selectedUnitType == 'all',
                          onSelected: (val) =>
                              setModalState(() => _selectedUnitType = 'all'),
                        ),
                        _FilterChip(
                          label: 'Hostel / PG',
                          isSelected: _selectedUnitType == 'hostel',
                          onSelected: (val) =>
                              setModalState(() => _selectedUnitType = 'hostel'),
                        ),
                        _FilterChip(
                          label: 'Flat',
                          isSelected: _selectedUnitType == 'flat',
                          onSelected: (val) =>
                              setModalState(() => _selectedUnitType = 'flat'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Location Filter
                    const Text(
                      'Location & Distance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GooglePlaceAutoCompleteTextField(
                      textEditingController: _locationController,
                      googleAPIKey:
                          "AIzaSyCESgiM55uOFhmtWlzz4jB0RPqkwCKprd8", // Replace with env var if possible
                      inputDecoration: InputDecoration(
                        hintText: "Search location...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: _filterLocation != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setModalState(() {
                                    _filterLocation = null;
                                    _locationController.clear();
                                  });
                                },
                              )
                            : null,
                      ),
                      debounceTime: 800,
                      countries: ["in"],
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (Prediction prediction) {
                        if (!mounted) return;
                        _locationController.text = prediction.description ?? "";
                        if (prediction.lat != null && prediction.lng != null) {
                          final lat = double.tryParse(prediction.lat!) ?? 0.0;
                          final lng = double.tryParse(prediction.lng!) ?? 0.0;
                          setModalState(() {
                            _filterLocation = LatLng(lat, lng);
                            // Auto-select sort by distance if location selected
                            if (_sortBy != 'distance') _sortBy = 'distance';
                          });
                        }
                      },
                      itemClick: (Prediction prediction) {
                        if (!mounted) return;
                        _locationController.text = prediction.description ?? "";
                        _locationController.selection =
                            TextSelection.fromPosition(
                              TextPosition(
                                offset: prediction.description?.length ?? 0,
                              ),
                            );
                      },
                    ),
                    if (_filterLocation != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Distance Radius'),
                          Text(
                            '${_filterRadius.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryRed,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _filterRadius,
                        min: 1.0,
                        max: 10.0,
                        divisions: 9, // 1km steps
                        label: '${_filterRadius.round()} km',
                        activeColor: AppTheme.primaryRed,
                        onChanged: (val) {
                          setModalState(() {
                            _filterRadius = val;
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Sort Options
                    const Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SortOption(
                      label: 'Top Rated',
                      value: 'rating_desc',
                      groupValue: _sortBy,
                      onChanged: (val) => setModalState(() => _sortBy = val!),
                    ),
                    _SortOption(
                      label: 'Price: Low to High',
                      value: 'price_asc',
                      groupValue: _sortBy,
                      onChanged: (val) => setModalState(() => _sortBy = val!),
                    ),
                    _SortOption(
                      label: 'Price: High to Low',
                      value: 'price_desc',
                      groupValue: _sortBy,
                      onChanged: (val) => setModalState(() => _sortBy = val!),
                    ),
                    // Distance sort option (only enabled if location selected)
                    Opacity(
                      opacity: _filterLocation != null ? 1.0 : 0.5,
                      child: _SortOption(
                        label: 'Distance: Nearest First',
                        value: 'distance',
                        groupValue: _sortBy,
                        onChanged: _filterLocation != null
                            ? (val) => setModalState(() => _sortBy = val!)
                            : (_) {}, // Disable if no location
                      ),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isFiltering =
                                _selectedUnitType != 'all' ||
                                _sortBy != 'rating_desc' ||
                                _filterLocation != null;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedUnitType = 'all';
                            _sortBy = 'rating_desc';
                            _filterLocation = null;
                            _filterRadius = 5.0;
                            _locationController.clear();
                          });
                          setState(() {
                            _isFiltering = false;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Reset All'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Hostels and Flats')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Colors.black87,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GooglePlaceAutoCompleteTextField(
                            textEditingController: _searchController,
                            googleAPIKey:
                                "AIzaSyCESgiM55uOFhmtWlzz4jB0RPqkwCKprd8",
                            inputDecoration: InputDecoration(
                              hintText: 'Search by name, city, or landmark...',
                              hintStyle: const TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _filterLocation = null;
                                          _lastSelectedPlace = null;
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            debounceTime: 800,
                            countries: ["in"],
                            isLatLngRequired: true,
                            getPlaceDetailWithLatLng: (Prediction prediction) {
                              if (!mounted) return;
                              _searchController.text =
                                  prediction.description ?? "";
                              _searchController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _searchController.text.length,
                                    ),
                                  );

                              if (prediction.lat != null &&
                                  prediction.lng != null) {
                                final lat =
                                    double.tryParse(prediction.lat!) ?? 0.0;
                                final lng =
                                    double.tryParse(prediction.lng!) ?? 0.0;
                                setState(() {
                                  _filterLocation = LatLng(lat, lng);
                                  _filterRadius = 3.0; // < 3km requirement
                                  _sortBy = 'distance';
                                  _searchQuery = prediction.description ?? "";
                                  _lastSelectedPlace = prediction.description;
                                });
                              }
                            },
                            itemClick: (Prediction prediction) {
                              if (!mounted) return;
                              _searchController.text =
                                  prediction.description ?? "";
                              _searchController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _searchController.text.length,
                                    ),
                                  );
                            },
                            boxDecoration: const BoxDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _isFiltering
                        ? AppTheme.primaryRed
                        : AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: _isFiltering ? AppTheme.white : AppTheme.grey,
                    ),
                    onPressed: _showFilterDialog,
                  ),
                ),
              ],
            ),
          ),

          // Soft Divider
          Container(
            height: 1,
            width: double.infinity,
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.black.withOpacity(0.06),
            ),
          ),
          const SizedBox(height: 8),

          // Results
          Expanded(
            child: StreamBuilder<List<HostelModel>>(
              stream: _firestoreService.getEnhancedHostels(
                query:
                    (_lastSelectedPlace != null &&
                        _searchQuery == _lastSelectedPlace)
                    ? null
                    : _searchQuery,
                unitType: _selectedUnitType,
                sortBy: _sortBy,
                lat: _filterLocation?.latitude,
                lng: _filterLocation?.longitude,
                radiusInKm: _filterLocation != null ? _filterRadius : null,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Searching...');
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppTheme.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hostels found',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                final hostels = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: hostels.length,
                  itemBuilder: (context, index) {
                    final hostel = hostels[index];
                    double? dist;
                    if (_filterLocation != null &&
                        hostel.latitude != null &&
                        hostel.longitude != null) {
                      dist =
                          Geolocator.distanceBetween(
                            _filterLocation!.latitude,
                            _filterLocation!.longitude,
                            hostel.latitude!,
                            hostel.longitude!,
                          ) /
                          1000;
                    } else if (_currentPosition != null &&
                        hostel.latitude != null &&
                        hostel.longitude != null) {
                      dist =
                          Geolocator.distanceBetween(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            hostel.latitude!,
                            hostel.longitude!,
                          ) /
                          1000;
                    }

                    return HotelCard(hostel: hostel, distance: dist);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppTheme.primaryRed.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryRed,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryRed : AppTheme.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _SortOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppTheme.primaryRed,
      contentPadding: EdgeInsets.zero,
    );
  }
}
