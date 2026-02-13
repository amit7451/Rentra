import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/loading_indicator.dart';
import 'package:rentra/services/user_cache.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  void _editProfile(
    BuildContext context,
    UserModel userModel,
    FirestoreService firestoreService,
  ) {
    final nameController = TextEditingController(text: userModel.name);
    final photoController = TextEditingController(
      text: userModel.photoUrl ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await firestoreService.updateUser(userModel.uid, {
                'name': nameController.text.trim(),
                'photoUrl': photoController.text.trim().isEmpty
                    ? null
                    : photoController.text.trim(),
              });
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Profile updated')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changePassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) return;

    await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();
    final firestoreService = FirestoreService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _showLogoutDialog(context, authService);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const LoadingIndicator(message: 'Loading profile...');
          }

          final userModel = UserModel.fromMap(snapshot.data!.data()!);

          return RefreshIndicator(
            color: AppTheme.primaryRed,
            onRefresh: () async =>
                await Future.delayed(const Duration(seconds: 1)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.primaryRed,
                    child: userModel.photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              userModel.photoUrl!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person,
                                size: 60,
                                color: AppTheme.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: AppTheme.white,
                          ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    userModel.name,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    user.email ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.grey),
                  ),

                  const SizedBox(height: 32),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.person_outline,
                            color: AppTheme.primaryRed,
                          ),
                          title: const Text('Edit Profile'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _editProfile(
                            context,
                            userModel,
                            firestoreService,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.lock_outline,
                            color: AppTheme.primaryRed,
                          ),
                          title: const Text('Change Password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _changePassword(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.notifications_outlined,
                            color: AppTheme.primaryRed,
                          ),
                          title: const Text('Notifications'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to notifications
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Notification settings coming soon',
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.payment_outlined,
                            color: AppTheme.primaryRed,
                          ),
                          title: const Text('Payment Methods'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to payment methods

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Payment methods feature coming soon',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // App settings
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.language_outlined,
                            color: AppTheme.primaryRed,
                          ),
                          title: const Text('Language'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'English',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.grey),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Language settings coming soon'),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.help_outline,
                            color: AppTheme.primaryRed,
                          ),
                          title: const Text('Help & Support'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Help & support feature coming soon',
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.privacy_tip_outlined,
                            color: AppTheme.primaryRed,
                          ),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Privacy policy feature coming soon',
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.info_outline,
                            color: AppTheme.primaryRed,
                          ),
                          title: const Text('About'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _showAboutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showLogoutDialog(context, authService);
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.darkRed,
                        side: const BorderSide(color: AppTheme.darkRed),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Version info
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.grey),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await authService.signOut();
                UserCache.clear();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to logout: $e'),
                      backgroundColor: AppTheme.darkRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Hostel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hostel Booking App'),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Find and book amazing hostels around the world with ease. Your perfect stay is just a tap away!',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
