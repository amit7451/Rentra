import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/theme.dart';
import '../../services/update_service.dart';

class InviteEarnScreen extends StatefulWidget {
  const InviteEarnScreen({super.key});

  @override
  State<InviteEarnScreen> createState() => _InviteEarnScreenState();
}

class _InviteEarnScreenState extends State<InviteEarnScreen> {
  String? _appLink;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppLink();
  }

  Future<void> _loadAppLink() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (mounted) {
      setState(() {
        _appLink = updateInfo?['apk_url'] ?? "https://rentra.com/download";
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_appLink != null) {
      Clipboard.setData(ClipboardData(text: _appLink!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareContent() async {
    if (_appLink != null) {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Hey! I found this amazing app for booking hostels and flats. Check it out: $_appLink',
          subject: 'Stay with Rentra',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite & Earn')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      size: 80,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Invite Friends & Earn Points',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Share your invite link with your friends and get rewarded when they sign up and book their first stay!',
                    style: TextStyle(
                      color: AppTheme.grey,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.lightGrey),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _appLink ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            color: AppTheme.primaryRed,
                          ),
                          onPressed: _copyToClipboard,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _shareContent,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share Now'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _benefitItem(
                    Icons.person_add_outlined,
                    'Step 1: Invite Friends',
                    'Share your link with friends who are looking for a place to stay.',
                  ),
                  const SizedBox(height: 20),
                  _benefitItem(
                    Icons.verified_user_outlined,
                    'Step 2: They Sign Up',
                    'Your friends sign up using your link and verified their account.',
                  ),
                  const SizedBox(height: 20),
                  _benefitItem(
                    Icons.stars_rounded,
                    'Step 3: Earn Rewards',
                    'Get 100 points for every successful booking they make!',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _benefitItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryRed, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
