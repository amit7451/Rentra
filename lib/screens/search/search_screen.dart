import 'package:flutter/material.dart';
import 'dart:async';
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
  final FocusNode _searchFocus = FocusNode();

  // Debounced search to avoid full state rebuilds while typing
  final ValueNotifier<String> _debouncedSearchNotifier = ValueNotifier<String>(
    '',
  );
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _debouncedSearchNotifier.value = _searchController.text;
      }
    });
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _locationController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    _debouncedSearchNotifier.dispose();
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
                      googleAPIKey: "AIzaSyCESgiM55uOFhmtWlzz4jB0RPqkwCKprd8",
                      inputDecoration: InputDecoration(
                        hintText: "Search location...",
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      debounceTime: 800,
                      countries: ["in"],
                      isLatLngRequired: false,
                      getPlaceDetailWithLatLng: (Prediction prediction) {
                        if (!mounted) return;
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
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 4,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.grey[50],
            title: const Text(
              'Search Hostels and Flats',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GooglePlaceAutoCompleteTextField(
                          textEditingController: _searchController,
                          focusNode: _searchFocus,
                          googleAPIKey:
                              "AIzaSyCESgiM55uOFhmtWlzz4jB0RPqkwCKprd8",
                          inputDecoration: InputDecoration(
                            hintText: 'Search by name, city, or landmark...',
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
                          countries: ["in"],
                          isLatLngRequired: false,
                          getPlaceDetailWithLatLng: (Prediction prediction) {
                            if (!mounted) return;
                            final desc = prediction.description ?? "";

                            // Dismiss keyboard and suggestions
                            FocusScope.of(context).unfocus();

                            if (prediction.lat != null &&
                                prediction.lng != null) {
                              final lat =
                                  double.tryParse(prediction.lat!) ?? 0.0;
                              final lng =
                                  double.tryParse(prediction.lng!) ?? 0.0;
                              setState(() {
                                _filterLocation = LatLng(lat, lng);
                                _filterRadius = 3.0;
                                _sortBy = 'distance';
                                _searchQuery = desc;
                                _lastSelectedPlace = desc;
                                _debouncedSearchNotifier.value = desc;
                              });
                            }
                          },
                          itemClick: (Prediction prediction) {
                            if (!mounted) return;
                            FocusScope.of(context).unfocus();
                          },
                          boxDecoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
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
                            color: _isFiltering
                                ? AppTheme.white
                                : AppTheme.grey,
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
              ],
            ),
          ),

          // Results
          ValueListenableBuilder<String>(
            valueListenable: _debouncedSearchNotifier,
            builder: (context, query, child) {
              return StreamBuilder<List<HostelModel>>(
                stream: _firestoreService.getEnhancedHostels(
                  query:
                      (_lastSelectedPlace != null &&
                          query == _lastSelectedPlace)
                      ? null
                      : query,
                  unitType: _selectedUnitType,
                  sortBy: _sortBy,
                  lat: _filterLocation?.latitude,
                  lng: _filterLocation?.longitude,
                  radiusInKm: _filterLocation != null ? _filterRadius : null,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: LoadingIndicator(message: 'Searching...'),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(child: Text('Error: ${snapshot.error}')),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
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
                      ),
                    );
                  }

                  final hostels = snapshot.data!;

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
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

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: HotelCard(hostel: hostel, distance: dist),
                      );
                    }, childCount: hostels.length),
                  );
                },
              );
            },
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
