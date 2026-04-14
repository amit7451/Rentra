import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/loading_indicator.dart';
import 'package:rentra/services/user_cache.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  void _editProfile(BuildContext context, UserModel userModel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userModel: userModel),
      ),
    );
  }

  void _changePassword(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.changePassword);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view profile')),
      );
    }

    return Scaffold(
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

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                elevation: 0,
                scrolledUnderElevation: 4,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                floating: false,
                backgroundColor: Colors.grey[50],
                centerTitle: true,
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.black),
                    onPressed: () {
                      _showLogoutDialog(context, authService);
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: RefreshIndicator(
                  color: AppTheme.primaryTeal,
                  onRefresh: () async =>
                      await Future.delayed(const Duration(seconds: 1)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppTheme.primaryTeal,
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
                                  color: AppTheme.primaryTeal,
                                ),
                                title: const Text('Edit Profile'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _editProfile(context, userModel),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.lock_outline,
                                  color: AppTheme.primaryTeal,
                                ),
                                title: const Text('Change Password'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _changePassword(context),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.notifications_outlined,
                                  color: AppTheme.primaryTeal,
                                ),
                                title: const Text('Notifications'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.notificationSettings,
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.payment_outlined,
                                  color: AppTheme.primaryTeal,
                                ),
                                title: const Text('Payment Methods'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.paymentMethods,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.language_outlined,
                                  color: AppTheme.primaryTeal,
                                ),
                                title: const Text('Language'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'English',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppTheme.grey),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Select Language'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            title: const Text('English'),
                                            trailing: const Icon(
                                              Icons.check,
                                              color: AppTheme.primaryTeal,
                                            ),
                                            onTap: () => Navigator.pop(ctx),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.help_outline,
                                  color: AppTheme.primaryTeal,
                                ),
                                title: const Text('Help & Support'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.helpSupport,
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.privacy_tip_outlined,
                                  color: AppTheme.primaryTeal,
                                ),
                                title: const Text('Privacy Policy'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.privacyPolicy,
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.info_outline,
                                  color: AppTheme.primaryTeal,
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
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _showLogoutDialog(context, authService);
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Logout'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.darkTeal,
                              side: const BorderSide(color: AppTheme.darkTeal),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('app_config')
                              .doc('android')
                              .get(),
                          builder: (context, snapshot) {
                            String version = 'Loading...';
                            if (snapshot.hasData && snapshot.data!.exists) {
                              version =
                                  snapshot.data!.get('latest_version') ??
                                  '1.1.0';
                            }
                            return Text(
                              'Version $version',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.grey),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
                      backgroundColor: AppTheme.darkTeal,
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

  void _showAboutDialog(BuildContext context) async {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('android')
        .get();
    String firebaseVersion = doc.data()?['latest_version'] ?? 'Unknown';

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('About Rentra'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rentra',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Version (Latest):',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                firebaseVersion,
                style: const TextStyle(color: AppTheme.grey, fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'Developed by:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              _DeveloperInfo(
                name: 'Amit Kumar',
                linkedinUrl: 'https://www.linkedin.com/in/amit-devspace/',
                githubUrl: 'https://github.com/amit7451',
              ),
              const SizedBox(height: 16),
              _DeveloperInfo(
                name: 'Anurag Shrivastav',
                linkedinUrl:
                    'https://www.linkedin.com/in/anurag-shrivastav-b7a616327/',
                githubUrl: 'https://github.com/Anurag-spec1',
              ),
              const SizedBox(height: 20),
              const Text(
                'Find and book amazing hostels around the world with ease. Your perfect stay is just a tap away!',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
            ],
          ),
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

class _DeveloperInfo extends StatelessWidget {
  final String name;
  final String linkedinUrl;
  final String githubUrl;

  const _DeveloperInfo({
    required this.name,
    required this.linkedinUrl,
    required this.githubUrl,
  });

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _SocialIcon(
              assetPath: 'assets/images/linkedin.png',
              iconData: Icons.link,
              onTap: () => _launchUrl(linkedinUrl),
              color: const Color(0xFF0077B5),
            ),
            const SizedBox(width: 16),
            _SocialIcon(
              assetPath: 'assets/images/github.png',
              iconData: Icons.code,
              onTap: () => _launchUrl(githubUrl),
              color: Colors.black,
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final String assetPath;
  final IconData iconData;
  final VoidCallback onTap;
  final Color color;

  const _SocialIcon({
    required this.assetPath,
    required this.iconData,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Image.asset(
        assetPath,
        width: 28,
        height: 28,
        errorBuilder: (context, error, stackTrace) =>
            Icon(iconData, size: 28, color: color),
      ),
    );
  }
}
