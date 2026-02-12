import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/theme.dart';
import '../app/routes.dart';
import '../screens/main/main_bottom_nav.dart';
import '../models/user_model.dart';

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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MainBottomNav(initialIndex: 3),
                  ),
                );
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

            _drawerItem(Icons.settings, 'Settings', () {}),
            _drawerItem(Icons.help_outline, 'Help & Support', () {}),
            _drawerItem(Icons.system_update, 'Update App', () {}),
            _drawerItem(Icons.language, 'Change Language', () {}),
            _drawerItem(Icons.privacy_tip_outlined, 'Privacy Policy', () {}),
            _drawerItem(Icons.card_giftcard, 'Invite & Earn', () {}),

            const Spacer(),
            const Divider(),

            _drawerItem(Icons.logout, 'Log out', () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;

              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
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
