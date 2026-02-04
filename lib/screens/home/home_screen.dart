import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_text.dart';
import 'hotel_card.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentra',style: TextStyle(fontSize: 30),),
        elevation: 5,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            color: AppTheme.primaryRed,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find Your Perfect Home',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Discover amazing hostels and flats around you',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Search bar (decorative, actual search in search screen)
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    readOnly: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(),
                        ),
                      );
                      DefaultTabController.of(context).animateTo(1);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search for hostels...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Text("Login Successful.\nWelcome to DashBoard",style: TextStyle(color: Colors.black,fontSize: 40),)

          // Hostels list
          Expanded(
            child: StreamBuilder<List<HostelModel>>(
              stream: firestoreService.getHostels(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator(message: 'Loading hostels...');
                }

                if (snapshot.hasError) {
                  return ErrorText(
                    message: 'Error loading hostels: ${snapshot.error}',
                    onRetry: () {
                      // Trigger rebuild
                    },
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.hotel_outlined,
                          size: 64,
                          color: AppTheme.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hostels available',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                }

                final hostels = snapshot.data!;

                return RefreshIndicator(
                  color: AppTheme.primaryRed,
                  onRefresh: () async {
                    // The stream automatically updates
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    itemCount: hostels.length,
                    itemBuilder: (context, index) {
                      return HotelCard(hostel: hostels[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}