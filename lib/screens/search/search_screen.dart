import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import '../home/hotel_card.dart';
import '../../widgets/glass_card.dart';

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
  final String _sortBy = 'distance'; // Default for map-like search
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
      if (mounted && !_isDisposed) {
        setState(() => _isLoadingSuggestions = false);
      }
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
      if (mounted) {
        setState(() => _errorMessage = "Could not fetch location details");
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,

      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F2F31), Color(0xFF184A4C)],
            ),
          ),
        ),
        title: Text(
          "Search for Hostels/Flats",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. SEARCH BAR
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF184A4C),
                    Color(0xFF184A4C),
                  ], // keep teal background
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          filled:
                              false, // Ensures no overlapping theme background
                          hintText: "Search places, landmarks...",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
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
                      color: AppTheme.primaryTeal,
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
                        style: const TextStyle(color: AppTheme.primaryTeal),
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
                        bottom: 120,
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
                                  backgroundColor: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  foregroundColor: AppTheme.primaryTeal,
                                  side: const BorderSide(
                                    color: AppTheme.primaryTeal,
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
                          child: PremiumHostelCard(
                            hostel: hostel,
                            distance: distance,
                          ),
                        );
                      },
                    ),

                  // B. Suggestions Overlay (Top)
                  if (_showSuggestions)
                    Positioned.fill(
                      child: Container(
                        color: isDark
                            ? const Color(0xFF1A1A1A).withValues(alpha: 0.95)
                            : Colors.white.withValues(
                                alpha: 0.95,
                              ), // Adapt to theme
                        child: _isLoadingSuggestions
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.separated(
                                itemCount: _placeSuggestions.length,
                                separatorBuilder: (ctx, i) => Divider(
                                  height: 1,
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[300],
                                ),
                                itemBuilder: (context, index) {
                                  final suggestion = _placeSuggestions[index];
                                  final mainText =
                                      suggestion['structured_formatting']['main_text'];
                                  final secondaryText =
                                      suggestion['structured_formatting']['secondary_text'] ??
                                      "";

                                  return ListTile(
                                    leading: Icon(
                                      Icons.location_on_outlined,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey,
                                    ),
                                    title: Text(
                                      mainText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      secondaryText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return GlassCard(
              customBorderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Search Radius',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_filterRadius.round()} km',
                        style: const TextStyle(
                          color: Color.fromARGB(255, 34, 224, 234),
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
                    activeColor: const Color.fromARGB(255, 34, 224, 234),
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      setModalState(() => _filterRadius = val);
                    },
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Unit Type',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
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

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          34,
                          224,
                          234,
                        ),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                        if (_selectedLocation != null) {
                          _executeSearch();
                        }
                      },
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
      selectedColor: const Color.fromARGB(
        255,
        34,
        224,
        234,
      ).withValues(alpha: 0.2),
      checkmarkColor: const Color.fromARGB(255, 34, 224, 234),
      labelStyle: TextStyle(
        color: isSelected
            ? const Color.fromARGB(255, 34, 224, 234)
            : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      side: BorderSide(
        color: isSelected
            ? const Color.fromARGB(255, 34, 224, 234)
            : Colors.white12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
