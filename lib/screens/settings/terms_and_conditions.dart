import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:listen_iq/screens/components/appbar.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isAccepted = false;

  final String githubUrl = 'https://github.com/Team-Manusmriti';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Terms & Conditions',
        isInChat: false,
        onBackPressed: () => Navigator.pop(context),
        onMenuPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSection(
                    '1. Our On-Device Philosophy and Data Privacy',
                    _buildPrivacyContent(),
                  ),
                  _buildSection(
                    '2. License to Use the App',
                    _buildLicenseContent(),
                  ),
                  _buildSection(
                    '3. User Responsibilities',
                    _buildUserResponsibilitiesContent(),
                  ),
                  _buildSection(
                    '4. Intellectual Property and Open-Source Components',
                    _buildIntellectualPropertyContent(),
                  ),
                  _buildSection(
                    '5. Disclaimers and Limitation of Liability',
                    _buildDisclaimersContent(),
                  ),
                  _buildSection('6. Termination', _buildTerminationContent()),
                  _buildSection(
                    '7. Governing Law',
                    _buildGoverningLawContent(),
                  ),
                  _buildSection(
                    '8. Changes to These Terms',
                    _buildChangesContent(),
                  ),
                  _buildSection('9. Contact Us', _buildContactContent()),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Terms and Conditions for the Manusmriti AI Companion',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Effective Date: September 13, 2025',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome to the AI Companion by Team Manusmriti. We are proud to offer you an intelligent assistant built on the principles of privacy, user control, and on-device processing.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'By downloading, installing, accessing, or using our application ("App"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree with any part of these terms, you may not use our App.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Our core principle is privacy-first. Unlike other AI assistants, our App is designed to be an "Untethered, Always-On AI Companion." This means:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        _buildBulletPoint(
          'On-Device Processing',
          'All core AI processing, including voice recognition, object detection, and conversation context, is performed exclusively on your device.',
        ),
        _buildBulletPoint(
          'No Cloud Data Storage',
          'Your personal data, such as conversations, images, or video feeds analyzed by the App, is never sent to our servers or any third-party cloud service. It remains on your device under your control.',
        ),
        _buildBulletPoint(
          'We Cannot Access Your Data',
          'As builders of this project, we have architected the App in such a way that we do not have access to your personal content. We cannot see what you see or hear what you hear. You own and control your data, period.',
        ),
      ],
    );
  }

  Widget _buildLicenseContent() {
    return Text(
      'We grant you a revocable, non-exclusive, non-transferable, limited license to download, install, and use the App for your personal, non-commercial purposes strictly in accordance with these Terms. This license is granted to you in line with the open-source licenses of the components we use.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildUserResponsibilitiesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By using this App, you agree to the following:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        _buildBulletPoint(
          '',
          'You will use the App in compliance with all applicable local, state, national, and international laws.',
        ),
        _buildBulletPoint(
          '',
          'You are solely responsible for the data and content you process through the App and for the security of your device.',
        ),
        _buildBulletPoint(
          '',
          'You will not use the App for any malicious, harmful, or unlawful activities.',
        ),
        _buildBulletPoint(
          '',
          'You will not attempt to decompile, reverse engineer, or disassemble the compiled application, except to the extent that such activity is expressly permitted by applicable law or the open-source licenses governing the App\'s components.',
        ),
      ],
    );
  }

  Widget _buildIntellectualPropertyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint(
          'Our Property',
          'The App, its original code, branding, and user interface are the intellectual property of Team Manusmriti and are protected by copyright and other intellectual property laws.',
        ),
        _buildBulletPoint(
          'Your Property',
          'You retain 100% ownership of the personal data you generate and process through the App.',
        ),
        _buildBulletPoint(
          'Open-Source Software',
          'The App is built upon powerful open-source projects. We gratefully acknowledge these projects. Key components like YoloV8s-oiv7, Vosk API, Flutter, and TensorFlow Lite are governed by their own open-source licenses (e.g., GPL-3.0, Apache 2.0). Our use of these components complies with their respective terms.',
        ),
      ],
    );
  }

  Widget _buildDisclaimersContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The App is provided "AS IS" and "AS AVAILABLE," without any warranties of any kind, express or implied. We do not warrant that the App will be error-free, uninterrupted, or completely secure.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'The AI models may produce inaccurate or unexpected results. You agree to use the App at your own risk.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'To the fullest extent permitted by law, in no event shall Team Manusmriti or its members be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or in connection with your use of the App.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildTerminationContent() {
    return Text(
      'We may terminate or suspend your access to the App immediately, without prior notice, if you breach these Terms. You may terminate these Terms at any time by uninstalling the App from your device.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildGoverningLawContent() {
    return Text(
      'These Terms shall be governed and construed in accordance with the laws of India. Any legal action or proceeding arising under these Terms will be brought exclusively in the courts located in India.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildChangesContent() {
    return Text(
      'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. We will notify you of any changes by posting the new Terms and Conditions within the App or on our official project page. Your continued use of the App after any such changes constitutes your acceptance of the new Terms.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildContactContent() {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          const TextSpan(
            text:
                'If you have any questions about these Terms, please contact us via our ',
          ),
          TextSpan(
            text: 'GitHub repository',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _launchGitHub(),
          ),
          const TextSpan(
            text:
                ' or at an official email address provided there.\n\nTeam Manusmriti',
          ),
        ],
      ),
    );
  }

  Future<void> _launchGitHub() async {
    final Uri url = Uri.parse(githubUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open GitHub repository'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildBulletPoint(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 8),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  if (title.isNotEmpty)
                    TextSpan(
                      text: '$title: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: content),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: _isAccepted,
                onChanged: (value) {
                  setState(() {
                    _isAccepted = value ?? false;
                  });
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAccepted = !_isAccepted;
                    });
                  },
                  child: Text(
                    'I have read and agree to the Terms and Conditions',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAccepted
                  ? () {
                      // Handle acceptance
                      Navigator.of(context).pop(true);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Accept and Continue',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _isAccepted
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
