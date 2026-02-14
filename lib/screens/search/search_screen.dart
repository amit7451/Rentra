import 'package:flutter/material.dart';
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
  final _searchController = TextEditingController();
  final _firestoreService = FirestoreService();

  String _searchQuery = '';
  String _selectedUnitType = 'all'; // 'all', 'hostel', 'flat'
  String _sortBy = 'rating_desc'; // 'rating_desc', 'price_asc', 'price_desc'
  bool _isFiltering = false;

  @override
  void dispose() {
    _searchController.dispose();
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
            return Padding(
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                  // Sort Options
                  const Text(
                    'Sort By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isFiltering =
                              _selectedUnitType != 'all' ||
                              _sortBy != 'rating_desc';
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Hostels')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, city, or country...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
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

          // Results
          Expanded(
            child: StreamBuilder<List<HostelModel>>(
              stream: _firestoreService.getEnhancedHostels(
                query: _searchQuery,
                unitType: _selectedUnitType,
                sortBy: _sortBy,
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
                    return HotelCard(hostel: hostels[index]);
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
