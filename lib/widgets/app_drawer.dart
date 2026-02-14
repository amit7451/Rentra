import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/theme.dart';
import '../app/routes.dart';
import '../models/user_model.dart';
import '../services/update_service.dart';

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

                  final userModel = UserModel.fromMap(
                    snapshot.data!.data() as Map<String, dynamic>,
                  );

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primaryRed,
                          backgroundImage: userModel.photoUrl != null
                              ? NetworkImage(userModel.photoUrl!)
                              : null,
                          child: userModel.photoUrl == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userModel.name,
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
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Request sent. Wait for approval to list your property.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
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
