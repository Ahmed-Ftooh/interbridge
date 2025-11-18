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
          Text('Last Updated: November 16, 2025', style: textStyle),
          const SizedBox(height: AppSize.s16),
          Text(
            '1. Introduction',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'InterBridge ("we", "our", "us") provides real-time interpretation, document translation, and chat/call services. This Privacy Policy explains what data we collect, how we use it, and your choices.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '2. Data We Collect',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '- Account Data: Email, username, role (requester/interpreter)\n'
            '- Profile & Skill Data: Languages, fluency levels, specialization IDs, skill IDs\n'
            '- Verification Data (interpreters): Certificates (file + metadata), voice samples and prompts\n'
            '- Session & Usage: Chat messages, call metadata (channel IDs, timestamps, duration), document translation requests (text, optional file)\n'
            '- Device Permissions: Microphone access, push notification tokens (Firebase Messaging)\n'
            '- Generated or Uploaded Files: Voice recordings, translated documents, certificates\n'
            '- Technical: Auth tokens, error logs (non-sensitive), time stamps',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '3. How We Use Data',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '- Provide core features: chat, calls (Agora), document translation workflows\n'
            '- Match interpreters to requester needs (languages, specialization)\n'
            '- Generate and validate interpreter credentials (voice sample, certificates)\n'
            '- Send real-time notifications (Supabase channels, Firebase Messaging)\n'
            '- Improve reliability, debug issues, prevent fraud/abuse\n'
            '- Comply with legal obligations and platform abuse prevention',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '4. Data Sharing',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We do not sell personal data. Limited sharing occurs with: \n'
            '- Service Providers: Supabase (database/storage/realtime), Firebase (notifications), Agora (voice infrastructure)\n'
            '- Interpreters & Requesters: Only data necessary for active sessions (e.g., messages, language preferences)\n'
            '- Legal Authorities: If required by law or to protect rights/safety.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '5. Storage & Security',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Data is stored in Supabase-managed infrastructure. Uploaded files (documents, certificates, voice samples) reside in secured storage buckets. We implement authentication, role-based access, and transport encryption (TLS). No system is 100% secure; you share data at your discretion.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '6. Retention',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Account data persists while your account is active. Interpreter credential artifacts remain for verification. Chat and translation records may be retained for audit/service continuity. You may request deletion (except where retention is legally required).',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '7. Your Choices & Rights',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '- Access/Update: Adjust profile & language preferences within the app.\n'
            '- Revoke Permissions: Manage microphone/notifications via device settings.\n'
            '- Delete Account: Contact support to initiate removal.\n'
            '- Opt-Out Notifications: Toggle push notifications inside settings.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '8. Children',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'InterBridge is not directed to children under 16. Do not register if under the applicable age threshold.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '9. International Transfers',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Data may be processed in regions where Supabase/Firebase/Agora host infrastructure. Safeguards follow their compliance frameworks.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '10. Changes',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We may update this Policy. Continued use after changes indicates acceptance. A revision date reflects latest changes.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '11. Contact',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'For privacy inquiries or deletion requests, contact: support@interbridge.example (placeholder).',
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
