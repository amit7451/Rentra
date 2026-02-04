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
  RangeValues _priceRange = const RangeValues(0, 500);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
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

                  Text(
                    'Price Range (per night)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 16),

                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 500,
                    divisions: 50,
                    activeColor: AppTheme.primaryRed,
                    labels: RangeLabels(
                      '\$${_priceRange.start.round()}',
                      '\$${_priceRange.end.round()}',
                    ),
                    onChanged: (values) {
                      setModalState(() => _priceRange = values);
                    },
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$${_priceRange.start.round()}'),
                      Text('\$${_priceRange.end.round()}'),
                    ],
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isFiltering = true;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setModalState(() {
                          _priceRange = const RangeValues(0, 500);
                        });
                        setState(() {
                          _isFiltering = false;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Clear Filters'),
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
      appBar: AppBar(
        title: const Text('Search Hostels'),
      ),
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
                    color: _isFiltering ? AppTheme.primaryRed : AppTheme.lightGrey,
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
              stream: _isFiltering
                  ? _firestoreService.filterHostelsByPrice(
                minPrice: _priceRange.start,
                maxPrice: _priceRange.end,
              )
                  : _searchQuery.isEmpty
                  ? _firestoreService.getHostels()
                  : _firestoreService.searchHostels(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Searching...');
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
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