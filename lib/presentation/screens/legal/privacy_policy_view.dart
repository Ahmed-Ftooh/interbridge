import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: ColorManager.white,
        elevation: 0,
      ),
      body: const _PolicyBody(),
    );
  }
}

class _PolicyBody extends StatelessWidget {
  const _PolicyBody();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      height: 1.4,
      fontSize: AppSize.s14,
      color: ColorManager.textPrimary,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSize.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last Updated: May 1, 2026', style: textStyle),
          const SizedBox(height: AppSize.s16),
          Text(
            '1. Introduction',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Interbridge ("we," "our," or "us") is committed to protecting the privacy and security of our users\' data. This Privacy Policy governs the data collection, processing, and usage practices for the Interbridge platform, which connects medical professionals ("Healthcare Providers") with independent interpreters ("Interpreters").',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '2. Information We Collect',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '- Personal Information: Name, email address, phone number, professional credentials, and billing information.\n'
            '- Call Metadata: Call logs, timestamps, duration of sessions, and connection logs.\n'
            '- Protected Health Information (PHI): While we do not proactively store patient records, audio/video data transmitted during live sessions may contain PHI. We treat all streamed data as highly sensitive and subject to HIPAA regulations.\n'
            '- Technical Data: IP addresses, device identifiers, browser types, and usage statistics.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '3. How We Use Information',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Information is used to facilitate real-time connections, process payments through third-party gateways (Stripe/Payoneer), provide technical support, and maintain platform security.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '4. Data Storage and Security',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We implement industry-standard, HIPAA-compliant encryption (both in transit and at rest) to protect all data. Audio and video streams are routed securely through our infrastructure. If session recordings are enabled by the Healthcare Provider, they are stored symmetrically encrypted on compliance-verified cloud infrastructure.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '5. Sharing of Information',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We do not sell user data. Data is shared exclusively with:\n'
            '- Third-party payment processors (Stripe/Payoneer) strictly for billing and payouts.\n'
            '- Cloud and communication infrastructure providers necessary for app functionality.\n'
            '- Law enforcement or regulatory bodies, only when legally compelled and verified.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '6. User Rights',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Users have the right to request access, modification, or deletion of their personal data. Healthcare Providers are responsible for managing patient data rights under HIPAA.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s24),
          Center(
            child: Text(
              '© 2026 Interbridge. All rights reserved.',
              style: textStyle?.copyWith(color: ColorManager.textSecondary),
            ),
          ),
          const SizedBox(height: AppSize.s40),
        ],
      ),
    );
  }
}
