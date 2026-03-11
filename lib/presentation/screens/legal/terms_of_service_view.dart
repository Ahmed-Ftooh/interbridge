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
          Text('Last Updated: March 6, 2026', style: textStyle),
          const SizedBox(height: AppSize.s16),
          Text(
            '1. Acceptance of Terms',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'By creating an account or using any InterBridge services — including interpretation calls, chat messaging, document translation, organization management, or payment features — you agree to be bound by these Terms of Service. If you do not agree, do not use our services.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '2. Service Description',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'InterBridge is a healthcare interpretation platform that connects healthcare providers with professional medical interpreters. Our services include:\n'
            '- Real-time voice and video interpretation sessions\n'
            '- Chat messaging between requesters and interpreters\n'
            '- Document translation requests and submissions\n'
            '- Organization management for healthcare facilities\n'
            '- Automated interpreter matching based on language and specialization\n'
            '- Organization wallet funding and transaction management\n'
            '- Invoice generation and delivery\n'
            '\n'
            'InterBridge does not provide legal, medical, or emergency advice. Interpreters facilitate communication only and are not responsible for the content or accuracy of medical decisions.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '3. User Accounts & Eligibility',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'You must provide accurate and complete registration information. Interpreters warrant that all submitted credentials (certificates, qualifications, language proficiencies) are truthful and valid. You are solely responsible for maintaining the confidentiality of your login credentials and for all activity under your account.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '4. User Roles',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'InterBridge supports multiple user roles:\n'
            '- Interpreters: Professional interpreters who provide real-time interpretation services and must undergo credential verification\n'
            '- Doctors/Requesters: Healthcare providers who request interpretation services, either independently or through an organization\n'
            '- Organization Administrators: Manage healthcare organization accounts, invite doctors, oversee wallet funding, and monitor usage\n'
            '- Platform Administrators: InterBridge staff who review interpreter credentials, manage accounts, and maintain platform integrity',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '5. Interpreter Responsibilities',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Interpreters must: (a) maintain strict confidentiality of all session content, (b) provide accurate and impartial interpretation, (c) avoid misrepresentation of qualifications, (d) comply with applicable professional standards and codes of ethics, (e) promptly end sessions when unable to continue ethically or competently, and (f) complete the verification process (certificate submission, voice sample, assessment quiz) honestly.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '6. Requester & Doctor Responsibilities',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Requesters and doctors agree to: (a) use interpretation services for legitimate healthcare communication purposes, (b) not solicit unlawful interpretations or share prohibited content, (c) refrain from harassment, discrimination, or exploitation of interpreters, (d) honour organizational spending limits and usage policies when using services through an organization account.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '7. Organization Accounts',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Healthcare organizations may create accounts to manage interpretation services for their staff. Organization administrators may:\n'
            '- Invite doctors to join the organization via unique invite codes\n'
            '- Fund the organization wallet through Stripe-powered payments\n'
            '- Set spending limits for individual members\n'
            '- View call history, transaction records, and usage reports\n'
            '- Generate and send invoices for services consumed\n'
            '\n'
            'Organization administrators are responsible for ensuring their members comply with these Terms. Organizations may not resell or sublicense InterBridge services.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '8. Payments & Billing',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Organization wallet top-ups are processed securely through Stripe. By initiating a payment, you agree to Stripe\'s terms of service and authorize the charge to your selected payment method. All payments are in the currency displayed at the time of checkout. Refund policies, if applicable, will be communicated separately. InterBridge does not store your full payment card information; all sensitive payment data is handled by Stripe in accordance with PCI DSS standards.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '9. Prohibited Conduct',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'You may NOT: (a) reverse engineer, decompile, or disassemble the app; (b) attempt unauthorized access to other user accounts or platform systems; (c) transmit viruses, malware, or harmful code; (d) infringe on intellectual property rights; (e) exploit, harm, or endanger minors; (f) use the platform for emergency triage, time-critical crisis intervention, or as a substitute for certified emergency services; (g) create fraudulent accounts or submit false credentials; (h) abuse the payment system through chargebacks, fraudulent transactions, or unauthorized fund transfers; (i) scrape, harvest, or collect data from the platform without authorization.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '10. Content & Intellectual Property',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'The InterBridge application, including its design, branding, code, and documentation, is the intellectual property of InterBridge. You retain ownership of content you submit (messages, documents, certificates) and grant us a limited, non-exclusive license to store, process, and transmit that content solely for service delivery.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '11. Document Translation',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Translation accuracy may vary depending on document complexity, language pair, and interpreter expertise. You must independently verify the accuracy of any translated document before relying on it for legal, medical, or regulatory purposes.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '12. Voice, Video & Phone Call Features',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Interpretation calls use third-party infrastructure provided by Agora (voice/video) and Twilio (phone calls). Call quality and availability depend on network conditions and device capabilities. InterBridge is not intended for emergency communications — do not rely on our call services in emergency situations.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '13. Push Notifications',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We use OneSignal to deliver push notifications for incoming calls, assignment updates, and service alerts. You may disable notifications through your device settings or within the app, though this may affect your ability to receive time-sensitive call requests.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '14. Privacy',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Your use of InterBridge is also governed by our Privacy Policy, which describes how we collect, use, and protect your data. Continued use of the platform signifies your consent to those practices.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '15. Suspension & Termination',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We reserve the right to suspend or terminate accounts for violations of these Terms, including abuse, fraud, credential falsification, payment disputes, or security threats. Interpreter accounts may also be suspended pending credential review. You may request voluntary account deletion at any time through the app.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '16. Disclaimers',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Services are provided "AS IS" and "AS AVAILABLE" without warranties of any kind, whether express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, uninterrupted availability, or accuracy of interpretation.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '17. Limitation of Liability',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'To the fullest extent permitted by applicable law, InterBridge and its officers, employees, and partners shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of or inability to use the service, including but not limited to loss of data, revenue, or medical outcomes.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '18. Third-Party Services',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'InterBridge integrates with third-party services (Supabase, Agora, Stripe, OneSignal, Twilio, Firebase, Resend). Your use of features powered by these services is also subject to their respective terms and privacy policies. InterBridge is not responsible for third-party service outages or policy changes.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '19. Changes to Terms',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We may update these Terms of Service from time to time. Material changes will be communicated through the app or via email. Your continued use of InterBridge after the effective date of any changes constitutes acceptance of the updated Terms.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '20. Governing Law',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'These Terms shall be governed by and construed in accordance with applicable law. Local consumer protection laws may still apply regardless of the chosen jurisdiction.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '21. Contact Us',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'For questions about these Terms of Service, please contact us at: legal@interbridge.app',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s24),
          Center(
            child: Text(
              '© 2026 InterBridge. All rights reserved.',
              style: textStyle?.copyWith(color: ColorManager.textSecondary),
            ),
          ),
          const SizedBox(height: AppSize.s40),
        ],
      ),
    );
  }
}
