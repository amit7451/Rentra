import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/hostel_model.dart';
import '../../app/theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_text.dart';
import 'hotel_card.dart';
import '../search/search_screen.dart';
import '/widgets/app_drawer.dart';

import 'package:rentra/app/routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        elevation: 2,
        backgroundColor: AppTheme.primaryRed,
        centerTitle: true,

        // LEFT: Menu
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),

        // CENTER: LOGO
        title: Image.asset(
          'assets/icons/app_icon.png',
          height: 36,
          fit: BoxFit.contain,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
        ),

        // RIGHT: Icons
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: AppTheme.white),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.wishlist);
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppTheme.white),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.notifications);
            },
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔴 Red search container (ONLY search + nearby stays)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    readOnly: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                    decoration: InputDecoration(
                      hintText: 'Search hostels, flats...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppTheme.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Nearby stays text
                const Text(
                  'Nearby stays',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

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
                      setState(() {});
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
