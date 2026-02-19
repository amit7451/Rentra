import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart'; // Add this to pubspec.yaml
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
// Import your app files
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import '../home/hotel_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Controllers
  final _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final _firestoreService = FirestoreService();
  bool _isDisposed = false;

  // Google API Key
  final String _googleApiKey = dotenv.get('GOOGLE_MAPS_API_KEY');
  final _uuid = const Uuid();
  String _sessionToken = '12345';

  // State Variables
  List<dynamic> _placeSuggestions = [];
  List<HostelModel> _allFoundHostels = []; // Stores all fetched data
  int _displayedCount = 10; // For pagination
  bool _isLoadingSuggestions = false;
  bool _isLoadingResults = false;
  bool _showSuggestions = false;
  String? _errorMessage;

  // Search Context
  LatLng? _selectedLocation;
  String _selectedPlaceName = "";

  // Filters
  String _selectedUnitType = 'all';
  String _sortBy = 'distance'; // Default for map-like search
  double _filterRadius = 5.0;

  // Debounce for typing
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _sessionToken = _uuid.v4();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SEARCH LOGIC & API CALLS
  // ---------------------------------------------------------------------------

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Manage suggestion visibility
    if (_searchController.text.isEmpty) {
      setState(() {
        _placeSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    // Debounce API call
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty && _searchFocus.hasFocus) {
        _fetchPlaceSuggestions(_searchController.text);
      }
    });
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    setState(() => _isLoadingSuggestions = true);

    final request =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_googleApiKey&sessiontoken=$_sessionToken&components=country:in';

    try {
      final response = await http.get(Uri.parse(request));
      if (_isDisposed) return;

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'OK') {
          if (mounted) {
            setState(() {
              _placeSuggestions = result['predictions'];
              _showSuggestions = true;
              _isLoadingSuggestions = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching suggestions: $e");
    } finally {
      if (mounted && !_isDisposed)
        setState(() => _isLoadingSuggestions = false);
    }
  }

  Future<void> _onSuggestionSelected(String placeId, String description) async {
    // 1. UI Updates immediately
    setState(() {
      _searchController.text = description;
      _showSuggestions = false;
      _searchFocus.unfocus();
      _isLoadingResults = true;
      _placeSuggestions = [];
      _selectedPlaceName = description;
    });

    // 2. Fetch LatLng
    final request =
        'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId&fields=geometry&key=$_googleApiKey&sessiontoken=$_sessionToken';

    try {
      final response = await http.get(Uri.parse(request));
      if (_isDisposed) return;

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'OK') {
          final location = result['result']['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];

          if (mounted) {
            setState(() {
              _selectedLocation = LatLng(lat, lng);
              _sessionToken = _uuid.v4(); // Reset token after selection
            });

            // 3. Fetch Hostels
            await _executeSearch();
          }
        }
      }
    } catch (e) {
      if (mounted)
        setState(() => _errorMessage = "Could not fetch location details");
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoadingResults = true;
      _showSuggestions = false;
      _searchFocus.unfocus();
      _searchController.text = "Current Location";
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
        _selectedPlaceName = "Your Location";
        await _executeSearch();
      } else {
        setState(() {
          _isLoadingResults = false;
          _errorMessage = "Location permission denied";
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingResults = false;
        _errorMessage = "Error getting location";
      });
    }
  }

  Future<void> _executeSearch() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isLoadingResults = true;
      _errorMessage = null;
      _displayedCount = 10; // Reset pagination
    });

    try {
      final stream = _firestoreService.getEnhancedHostels(
        unitType: _selectedUnitType,
        sortBy: _sortBy, // Usually 'distance'
        lat: _selectedLocation!.latitude,
        lng: _selectedLocation!.longitude,
        radiusInKm: _filterRadius,
      );

      // Listen once to get data
      final snapshot = await stream.first;
      if (_isDisposed) return;

      if (mounted) {
        setState(() {
          _allFoundHostels = snapshot;
          _isLoadingResults = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingResults = false;
          _errorMessage = "Failed to load hostels: $e";
        });
      }
    }
  }

  void _loadMore() {
    setState(() {
      _displayedCount += 10;
    });
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Determine how many items to show based on pagination
    final visibleHostels = _allFoundHostels.take(_displayedCount).toList();
    final hasMore = _allFoundHostels.length > _displayedCount;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Search for Hostels/Flats",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. SEARCH BAR
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: "Search places, landmarks...",
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchFocus.requestFocus();
                                    setState(() {
                                      _showSuggestions = false;
                                      _selectedLocation = null;
                                    });
                                  },
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                  ),
                                  tooltip: "Use Current Location",
                                  onPressed: _useCurrentLocation,
                                ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) {
                          if (_placeSuggestions.isNotEmpty) {
                            final first = _placeSuggestions.first;
                            _onSuggestionSelected(
                              first['place_id'],
                              first['description'],
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _showFilterDialog,
                    ),
                  ),
                ],
              ),
            ),

            // 2. MAIN CONTENT STACK
            Expanded(
              child: Stack(
                children: [
                  // A. Results Layer (Bottom)
                  if (_isLoadingResults)
                    const Center(
                      child: LoadingIndicator(
                        message: 'Calculating distances...',
                      ),
                    )
                  else if (_errorMessage != null)
                    Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  else if (_selectedLocation == null &&
                      _searchController.text.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Search area to find hostels",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  else if (_allFoundHostels.isEmpty &&
                      _selectedLocation != null)
                    Center(
                      child: Text(
                        "No hostels found near $_selectedPlaceName",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    // THE HOSTEL LIST
                    ListView.builder(
                      padding: const EdgeInsets.only(
                        top: 16,
                        left: 16,
                        right: 16,
                        bottom: 80,
                      ),
                      itemCount: visibleHostels.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visibleHostels.length) {
                          // View More Button
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: ElevatedButton(
                                onPressed: _loadMore,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primaryRed,
                                  side: const BorderSide(
                                    color: AppTheme.primaryRed,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("View More Results"),
                              ),
                            ),
                          );
                        }

                        // Calculate display distance
                        final hostel = visibleHostels[index];
                        double distance = 0.0;
                        if (_selectedLocation != null &&
                            hostel.latitude != null &&
                            hostel.longitude != null) {
                          distance =
                              Geolocator.distanceBetween(
                                _selectedLocation!.latitude,
                                _selectedLocation!.longitude,
                                hostel.latitude!,
                                hostel.longitude!,
                              ) /
                              1000;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: HotelCard(hostel: hostel, distance: distance),
                        );
                      },
                    ),

                  // B. Suggestions Overlay (Top)
                  if (_showSuggestions)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(
                          0.95,
                        ), // Slight transparency
                        child: _isLoadingSuggestions
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.separated(
                                itemCount: _placeSuggestions.length,
                                separatorBuilder: (ctx, i) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final suggestion = _placeSuggestions[index];
                                  final mainText =
                                      suggestion['structured_formatting']['main_text'];
                                  final secondaryText =
                                      suggestion['structured_formatting']['secondary_text'] ??
                                      "";

                                  return ListTile(
                                    leading: const Icon(
                                      Icons.location_on_outlined,
                                      color: Colors.grey,
                                    ),
                                    title: Text(
                                      mainText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      secondaryText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _onSuggestionSelected(
                                      suggestion['place_id'],
                                      suggestion['description'],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER MODAL
  // ---------------------------------------------------------------------------

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Radius Slider (No Location Input here)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Search Radius',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_filterRadius.round()} km',
                        style: const TextStyle(
                          color: AppTheme.primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _filterRadius,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    activeColor: AppTheme.primaryRed,
                    onChanged: (val) {
                      setModalState(() => _filterRadius = val);
                    },
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Unit Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedUnitType == 'all',
                        onSelected: (_) =>
                            setModalState(() => _selectedUnitType = 'all'),
                      ),
                      _FilterChip(
                        label: 'Hostel / PG',
                        isSelected: _selectedUnitType == 'hostel',
                        onSelected: (_) =>
                            setModalState(() => _selectedUnitType = 'hostel'),
                      ),
                      _FilterChip(
                        label: 'Flat',
                        isSelected: _selectedUnitType == 'flat',
                        onSelected: (_) =>
                            setModalState(() => _selectedUnitType = 'flat'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        // Apply changes and re-run search if location is selected
                        setState(() {
                          /* triggers rebuild with new radius */
                        });
                        Navigator.pop(context);
                        if (_selectedLocation != null) {
                          _executeSearch();
                        }
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// HELPER WIDGETS
// ---------------------------------------------------------------------------

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
      selectedColor: AppTheme.primaryRed.withOpacity(0.1),
      checkmarkColor: AppTheme.primaryRed,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryRed : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[100],
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
