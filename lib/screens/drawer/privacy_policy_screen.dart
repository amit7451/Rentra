import 'package:flutter/material.dart';
import '../../app/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy for Rentra',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last updated: 19 February 2026',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Rentra respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, store, and protect user data when you use the Rentra mobile application (“App”).',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            _buildSection(
              '1. Information We Collect',
              'We collect only the information necessary to provide our services.',
            ),

            _buildSubSection(
              '1.1 Personal Information',
              'When you register or use the App, we may collect:\n'
                  '• Name\n'
                  '• Email address\n'
                  '• Profile photo\n'
                  '• Phone number (if provided)',
            ),

            _buildSubSection(
              '1.2 Location Information',
              'Approximate or precise location may be collected to:\n'
                  '• Show nearby flats/hostels\n'
                  '• Improve search results and map functionality\n\n'
                  'Location access is optional and can be controlled via device settings.',
            ),

            _buildSubSection(
              '1.3 User-Generated Content',
              '• Images uploaded by users (e.g., hostel photos)\n'
                  '• Property details and descriptions',
            ),

            _buildSubSection(
              '1.4 Device & Usage Information',
              '• Device type\n'
                  '• App usage events\n'
                  '• Crash logs and performance data',
            ),

            _buildSection(
              '2. How We Use Your Information',
              'We use collected data to:\n'
                  '• Create and manage user accounts\n'
                  '• Connect students with flat/hostel owners\n'
                  '• Display nearby rental listings\n'
                  '• Enable in-app communication and notifications\n'
                  '• Improve app performance and user experience\n'
                  '• Prevent misuse, fraud, or unauthorized access',
            ),

            _buildSection(
              '3. Third-Party Services',
              'Rentra uses trusted third-party services that may collect information as required to function properly.\n\n'
                  'Third-party services include:\n'
                  '• Firebase Authentication – user login and identity management\n'
                  '• Firebase Firestore – secure data storage\n'
                  '• Firebase Analytics & Crashlytics – app performance monitoring\n'
                  '• Google Maps SDK – location and map features\n'
                  '• OneSignal – push notifications\n'
                  '• Cloudinary – image storage and delivery\n\n'
                  'These services operate under their own privacy policies and comply with applicable data protection laws.',
            ),

            _buildSection(
              '4. Data Sharing & Disclosure',
              'We do not sell or rent personal data to third parties. Data may be shared only:\n'
                  '• When required by law or legal request\n'
                  '• To protect the rights, safety, or security of users or the App\n'
                  '• With service providers strictly for app functionality',
            ),

            _buildSection(
              '5. Data Storage & Security',
              'All user data is stored securely using industry-standard security practices. Access to data is restricted and role-based. We continuously monitor and improve security measures.',
            ),

            _buildSection(
              '6. User Rights & Data Control',
              'Users have the right to:\n'
                  '• Access their personal data\n'
                  '• Update or correct personal information\n'
                  '• Request deletion of their account and associated data\n\n'
                  'Data Deletion:\n'
                  'You can request data deletion by using in-app account deletion (if available), or emailing us at the contact address below. Data deletion requests are processed within a reasonable time.',
            ),

            _buildSection(
              '7. Notifications',
              'We may send notifications related to booking updates, property status, or important app information. Users can disable notifications anytime through device settings.',
            ),

            _buildSection(
              '8. Children’s Privacy',
              'Rentra is not intended for children under 18 years of age. We do not knowingly collect personal data from minors.',
            ),

            _buildSection(
              '9. Changes to This Policy',
              'We may update this Privacy Policy from time to time. Changes will be reflected on this page with an updated revision date.',
            ),

            _buildSection(
              '10. Contact Us',
              'If you have any questions or concerns about this Privacy Policy or your data, contact us at:',
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: AppTheme.primaryTeal,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'amitkumarstm1507@gmail.com',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
