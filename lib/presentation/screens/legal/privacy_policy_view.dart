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
          Text('Last Updated: March 6, 2026', style: textStyle),
          const SizedBox(height: AppSize.s16),
          Text(
            '1. Introduction',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'InterBridge ("we", "our", "us") provides a healthcare-focused interpretation platform that connects healthcare providers with professional medical interpreters through real-time voice/video calls, chat messaging, document translation, and organization management tools. This Privacy Policy explains what data we collect, how we use it, and your choices.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '2. Data We Collect',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'a) Account & Profile Data\n'
            '- Email address, username, and role (interpreter, doctor/requester, or organization administrator)\n'
            '- Languages, fluency levels, medical specialization preferences, and skill identifiers\n'
            '- Organization membership details (organization name, role within organization, invite codes)\n'
            '\n'
            'b) Verification Data (Interpreters)\n'
            '- Uploaded certificates (file and metadata), voice samples, and quiz/assessment results used for credential validation\n'
            '\n'
            'c) Communication & Session Data\n'
            '- Chat messages exchanged between requesters and interpreters\n'
            '- Call metadata: channel identifiers, timestamps, duration, and participant roles\n'
            '- Document translation requests (text content, optional file attachments)\n'
            '\n'
            'd) Payment & Billing Data\n'
            '- Organization wallet top-up transactions processed through Stripe\n'
            '- Transaction history, invoice records, and payment confirmation details\n'
            '- Stripe does not share full card numbers with us; we receive only confirmation tokens, last-four digits, and transaction status\n'
            '\n'
            'e) Device & Technical Data\n'
            '- Push notification tokens (OneSignal)\n'
            '- Microphone and camera permissions status\n'
            '- Authentication tokens, error logs (non-sensitive), and timestamps\n'
            '\n'
            'f) Email Communications\n'
            '- Email addresses used to deliver organization invite notifications and invoices via our email service provider',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '3. How We Use Data',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '- Provide core platform features: real-time interpretation calls, chat, and document translation\n'
            '- Match interpreters to healthcare provider requests based on language, specialization, and availability\n'
            '- Validate interpreter credentials through certificate review, voice verification, and assessment quizzes\n'
            '- Process organization wallet top-ups and generate invoices for interpretation services\n'
            '- Send push notifications for incoming calls, assignment updates, and service alerts via OneSignal\n'
            '- Deliver transactional emails (organization invitations, invoices) via Resend\n'
            '- Enable organization administrators to manage members, monitor usage, and invite healthcare providers\n'
            '- Support administrative functions: interpreter account review, suspension, and credential approval\n'
            '- Route incoming call requests to the best-matched available interpreter automatically\n'
            '- Improve service reliability, diagnose issues, and prevent fraud or abuse\n'
            '- Comply with legal obligations',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '4. Third-Party Service Providers',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We do not sell personal data. We share limited data with the following service providers solely to operate the platform:\n'
            '\n'
            '- Supabase: Database hosting, user authentication, real-time messaging, and file storage\n'
            '- Agora: Voice and video call infrastructure for live interpretation sessions\n'
            '- Stripe: Secure payment processing for organization wallet top-ups (Stripe handles card data under its own PCI-compliant privacy policy)\n'
            '- OneSignal: Push notification delivery to mobile and web clients\n'
            '- Resend: Transactional email delivery (organization invitations, invoices)\n'
            '- Twilio: Telephone call connectivity as an alternative communication channel\n'
            '- Firebase: Core app services and analytics\n'
            '\n'
            'Data is also shared between session participants (interpreters and requesters) as necessary to deliver the service, such as messages and language preferences.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '5. Payment Data',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Organization wallet top-ups are processed securely through Stripe. We do not store, process, or have access to full credit/debit card numbers. Stripe handles all sensitive payment information in accordance with PCI DSS standards. We retain only transaction references, amounts, timestamps, and payment status for invoicing and record-keeping purposes.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '6. Storage & Security',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Data is stored in Supabase-managed infrastructure with encryption at rest and in transit (TLS). Uploaded files (documents, certificates, voice samples) are stored in access-controlled storage buckets. We implement role-based access controls, row-level security policies, and secure authentication throughout the platform. No system is 100% secure; you share data at your own discretion.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '7. Data Retention',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '- Account data is retained while your account is active\n'
            '- Interpreter verification artifacts (certificates, voice samples) are retained for ongoing credential validation\n'
            '- Chat messages, call records, and translation history may be retained for service continuity, dispute resolution, and auditing\n'
            '- Payment and invoice records are retained as required by applicable financial record-keeping laws\n'
            '- You may request deletion of your account and associated data, except where retention is legally required',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '8. Your Rights & Choices',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '- Access & Update: Edit your profile, languages, and preferences within the app\n'
            '- Revoke Permissions: Manage microphone, camera, and notification permissions through your device settings\n'
            '- Delete Account: Request account deletion through the app settings; your data will be removed except where legal retention is required\n'
            '- Opt-Out of Notifications: Disable push notifications in app settings or device settings\n'
            '- Organization Data: Organization administrators may manage member data within their organization dashboard',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '9. Organization Data',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Healthcare organizations using InterBridge may invite doctors to join their organization. Organization administrators can view member activity, manage spending limits, and access call and transaction history for their organization. Members\' personal account data remains subject to this Privacy Policy.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '10. Children',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'InterBridge is designed for healthcare professionals and is not directed to individuals under the age of 16. If you are under 16, do not create an account or use our services.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '11. International Transfers',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Your data may be processed in regions where our service providers (Supabase, Agora, Stripe, OneSignal, Twilio, Firebase, Resend) operate their infrastructure, including the United States and the European Union. These providers maintain their own compliance frameworks and data protection safeguards.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '12. Changes to This Policy',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We may update this Privacy Policy from time to time. The "Last Updated" date at the top reflects the most recent revision. Continued use of InterBridge after changes are posted constitutes your acceptance of the updated policy.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '13. Contact Us',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'For privacy inquiries, data access requests, or account deletion requests, please contact us at: support@interbridge.app',
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
