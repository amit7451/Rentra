import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../widgets/glass_card.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F2F31), Color(0xFF184A4C)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We are here to help you with any issues or queries.',
              style: TextStyle(color: AppTheme.grey),
            ),
            const SizedBox(height: 32),
            _contactItem(
              context,
              Icons.email_outlined,
              'Email',
              'amitkumarstm1507@gmail.com',
              () => _launchEmail('amitkumarstm1507@gmail.com'),
            ),
            _contactItem(
              context,
              Icons.phone_outlined,
              'Phone',
              '+91 7323006476',
              () => _launchPhone('+917323006476'),
            ),
            _contactItem(
              context,
              Icons.chat_outlined,
              'WhatsApp',
              '+91 7323006476',
              () => _launchWhatsApp('+917323006476'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Business Hours',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '24*7',
              style: TextStyle(color: AppTheme.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: GlassCard(
          borderRadius: 12,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.getPriceColor(context)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Support Request - Rentra'},
    );
    if (!await launchUrl(emailLaunchUri)) {
      debugPrint('Could not launch email');
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneLaunchUri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(phoneLaunchUri)) {
      debugPrint('Could not launch phone dialer');
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Remove plus sign and spaces for WhatsApp API
    final String cleanPhone = phone.replaceAll(RegExp(r'[\s+]'), '');
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$cleanPhone?text=Hi Rentra Support, I need help with...",
    );
    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch WhatsApp');
    }
  }
}
