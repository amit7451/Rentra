import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app/theme.dart';
import '../app/routes.dart';
import '../screens/main/main_bottom_nav.dart';
import '../../services/user_cache.dart';
import 'package:rentra/models/user_model.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Text('Not logged in');
    }

    return Drawer(
      backgroundColor: AppTheme.white,
      child: SafeArea(
        child: Column(
          children: [
            // ================= PROFILE HEADER =================
            InkWell(
              onTap: () {
                Navigator.pop(context); // close drawer

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MainBottomNav(initialIndex: 3),
                  ),
                );
              },

              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryRed,
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 30,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<UserModel?>(
                        future: UserCache.getUser(),
                        builder: (context, snapshot) {
                          final userModel = snapshot.data;

                          final name = userModel?.name ?? 'User';
                          final email = userModel?.email ?? user.email ?? '';

                          return Expanded(
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
                                    color: AppTheme.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const Icon(Icons.chevron_right, color: AppTheme.grey),
                  ],
                ),
              ),
            ),

            const Divider(),

            // ================= MENU ITEMS =================
            _drawerItem(Icons.settings, 'Settings', () {}),
            _drawerItem(Icons.help_outline, 'Help & Support', () {}),
            _drawerItem(Icons.system_update, 'Update App', () {}),
            _drawerItem(Icons.language, 'Change Language', () {}),
            _drawerItem(Icons.privacy_tip_outlined, 'Privacy Policy', () {}),
            _drawerItem(Icons.card_giftcard, 'Invite & Earn', () {}),

            const Spacer(),

            const Divider(),

            // ================= LOGOUT =================
            _drawerItem(Icons.logout, 'Log out', () async {
              // 1️⃣ Sign out from Firebase
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              // 2️⃣ Close drawer
              Navigator.pop(context);

              // 3️⃣ Navigate to Login & clear stack
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

  // ================= DRAWER TILE =================
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
      horizontalTitleGap: 8,
    );
  }
}
