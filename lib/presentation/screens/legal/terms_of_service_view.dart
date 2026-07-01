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
          Text('Last Updated: May 1, 2026', style: textStyle),
          const SizedBox(height: AppSize.s16),
          Text(
            '1. Acceptance of Terms',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'By accessing or using Interbridge, you agree to comply with and be bound by these Terms of Service.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '2. Service Description',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Interbridge is a healthcare interpretation platform that connects healthcare providers with professional medical interpreters. Our services include real-time voice and video interpretation sessions, chat messaging between requesters and interpreters, document translation, organization management, and specific integrated billing processes.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '3. User Responsibilities & Account Security',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '- Healthcare Providers: Must ensure that their use of Interbridge complies with all applicable privacy laws (including HIPAA) and that they have obtained necessary patient consents.\n'
            '- Interpreters: Act as independent contractors. Must maintain confidentiality, professionalism, and comply with all non-disclosure obligations.\n'
            'Users are responsible for maintaining the confidentiality of their account credentials.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '4. Medical Disclaimer and Limitation of Liability',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Interbridge is strictly a communication technology platform. We do not provide medical advice, diagnosis, or treatment. We are not liable for any medical outcomes, miscommunications, or errors during interpretation. Healthcare Providers retain full professional responsibility for patient care. In no event shall Interbridge be liable for direct, indirect, incidental, or consequential damages arising from the use of the platform.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '5. Intellectual Property',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'All software, design, text, and graphics on Interbridge are owned by us. Users are granted a limited, non-exclusive license to use the platform. Our platform integrates third-party services like Agora, Supabase, Stripe, and Twilio, governed by their respective licenses and terms.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '6. Account Suspension and Termination',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'We reserve the right to suspend or terminate accounts immediately, without notice, for violations of these Terms, including but not limited to breach of confidentiality, unprofessional conduct, fraudulent payment activity, or unauthorized exploitation of platform features.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '7. Business Associate Agreement (BAA)',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Healthcare Providers ("Covered Entities") using Interbridge enter into a standard HIPAA-compliant BAA understanding that we ("Business Associate") apply physical, technical, and administrative safeguards for potential PHI handling and ensure subcontractors do the same. We commit to reporting security incidents within reasonable/mandated windows.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '8. Payment, Subscription & Refund Policy',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'All subscription fees and pay-per-call charges are processed securely through third-party payment providers (Stripe/Payoneer/etc.). By adding a payment method, you authorize automatic billing.\n'
            '- Refunds: All payments to Interbridge are strictly non-refundable. Exceptions are entirely at our discretion.\n'
            '- Payouts: Interpreters operate as independent contractors. Earnings map to call duration/agreed rates. Interpreters are solely responsible for local, state, and federal taxes.',
            style: textStyle,
          ),
          const SizedBox(height: AppSize.s12),
          Text(
            '9. End-User License Agreement (EULA)',
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Users are granted a limited, non-exclusive, non-transferable, revocable license to install and use the app. You may not reverse engineer, decompile, or illegally exploit the software. Platform usage is an agreement direct with Interbridge (not Apple or Google, though they are third-party beneficiaries). Automatic updates may apply.',
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
