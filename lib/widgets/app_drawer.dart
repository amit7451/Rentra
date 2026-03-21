import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../app/theme.dart';
import '../app/routes.dart';
import '../models/user_model.dart';
import '../services/update_service.dart';
import 'verification_dialog.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Drawer(
      backgroundColor: AppTheme.white,
      child: SafeArea(
        child: Column(
          children: [
            // 🔥 STREAM BASED HEADER
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.profile);
              },
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    );
                  }

                  final doc = snapshot.data!;
                  // Fallback to Auth data if Firestore doc missing or empty
                  String name = user.displayName ?? 'User';
                  String? photoUrl = user.photoURL;

                  if (doc.exists && doc.data() != null) {
                    try {
                      final userModel = UserModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                      );
                      name = userModel.name;
                      photoUrl = userModel.photoUrl;
                    } catch (_) {
                      // ignore parse errors
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primaryRed,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.grey),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(),

            _drawerItem(Icons.payment_rounded, 'Payments & Transactions', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.payments);
            }),

            _drawerItem(Icons.add_business_rounded, 'Add your property', () async {
              // Check email verification first
              await FirebaseAuth.instance.currentUser?.reload();
              final currentUser = FirebaseAuth.instance.currentUser;

              if (currentUser != null && !currentUser.emailVerified) {
                if (context.mounted) {
                  Navigator.pop(context); // Close drawer
                  showVerificationDialog(context);
                }
                return;
              }

              if (!context.mounted) return;

              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final isAdmin = userDoc.data()?['isAdmin'] == true;

              if (!context.mounted) return;

              if (isAdmin) {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.addHostel);
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Request Access'),
                    content: const Text(
                      'To list your property and become an admin, you need special permissions. Would you like to send a request?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sending request...'),
                            ),
                          );
                          
                          try {
                            final currentName = userDoc.data()?['name'] ?? currentUser?.displayName ?? 'Unknown Name';
                            final currentEmail = currentUser?.email ?? 'Unknown Email';
                            
                            await FirebaseFunctions.instance.httpsCallable('requestAdminAccess').call({
                              'name': currentName,
                              'email': currentEmail,
                            });
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request sent! Wait for approval to list your property.'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to send request: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Request'),
                      ),
                    ],
                  ),
                );
              }
            }),

            _drawerItem(Icons.help_outline, 'Help & Support', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.helpSupport);
            }),

            _drawerItem(Icons.system_update, 'Update App', () async {
              final updateInfo = await UpdateService.checkForUpdate();
              if (!context.mounted) return;

              if (updateInfo?['needs_update'] == true) {
                UpdateService.showUpdateDialog(
                  context,
                  updateInfo!['apk_url'],
                  updateInfo['force_update'],
                );
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Up to Date'),
                    content: const Text('Your app is already up to date!'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            }),

            _drawerItem(Icons.privacy_tip_outlined, 'Privacy Policy', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.privacyPolicy);
            }),

            _drawerItem(Icons.card_giftcard_rounded, 'Invite & Earn', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.inviteEarn);
            }),

            const Spacer(),
            const Divider(),

            _drawerItem(Icons.logout, 'Log out', () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              }
            }, isLogout: true),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : AppTheme.primaryRed),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: isLogout ? Colors.red : AppTheme.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
