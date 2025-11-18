import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class TermsOfServiceView extends StatelessWidget {
  const TermsOfServiceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: ColorManager.white,
        elevation: 0,
      ),
      body: const _TermsBody(),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

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
          Text('Last Updated: November 16, 2025', style: textStyle),
          const SizedBox(height: AppSize.s16),
          Text(
            '1. Acceptance of Terms',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'By creating an account or using InterBridge services (chat, calls, translation) you agree to these Terms.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '2. Service Scope',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'InterBridge facilitates live interpretation, document translation requests, and real-time messaging. We do not provide legal, medical, or emergency certified advice; interpreters act as facilitators only.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '3. User Accounts & Eligibility',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'You must provide accurate registration data. Interpreters warrant that submitted credentials are valid. You are responsible for safeguarding login credentials.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '4. Interpreter Responsibilities',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Interpreters must: (a) maintain confidentiality, (b) avoid misrepresentation, (c) comply with applicable professional standards, (d) promptly end sessions when unable to continue ethically.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '5. Requester Responsibilities',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Requesters agree not to solicit unlawful interpretations or submit prohibited content. You must refrain from harassment, exploitation, or sharing illegal material.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '6. Prohibited Conduct',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'You may NOT: reverse engineer the app; attempt unauthorized access; transmit malware; infringe intellectual property; exploit minors; use the platform for emergency triage or time-critical crisis intervention.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '7. Content & Intellectual Property',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'App UI, branding, and underlying code are owned by InterBridge. You grant us a limited license to store and transmit your submitted content solely for service delivery.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '8. Document Translation Requests',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Accuracy may vary; automated and human factors influence results. You must verify critical legal/medical documents independently.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '9. Voice & Call Features',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Calls leverage third-party infrastructure (Agora). Quality and availability depend on network conditions. Do not rely on calls for emergencies.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '10. No Payment Processing',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'The current version of InterBridge handles no in-app payments or billing. Any future payment integration will include updated terms.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '11. Privacy',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'See our Privacy Policy for data handling practices. Continued use signifies ongoing consent to those practices.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '12. Suspension & Termination',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We may suspend or terminate accounts for violations (abuse, fraud, credential falsification, security threats). You may request voluntary deletion.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '13. Disclaimers',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Services are provided “AS IS” without warranties of uninterrupted availability, accuracy, or fitness for a particular purpose.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '14. Limitation of Liability',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'To the fullest extent permitted by law, InterBridge is not liable for indirect, incidental, or consequential damages arising from use.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '15. Changes to Terms',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We may update these Terms. Material changes will be communicated; continued use after effective date constitutes acceptance.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '16. Governing Law',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Applicable jurisdiction to be determined (placeholder). Local consumer protections may still apply.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '17. Contact',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Questions: legal@interbridge.example (placeholder).',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s24),
          Center(
            child: Text(
              '© 2025 InterBridge',
              style: textStyle?.copyWith(color: ColorManager.textSecondary),
            ),
          ),
          const SizedBox(height: AppSize.s40),
        ],
      ),
    );
  }
}
