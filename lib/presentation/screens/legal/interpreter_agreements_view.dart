import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class InterpreterAgreementsView extends StatefulWidget {
  final VoidCallback onAccept;

  const InterpreterAgreementsView({super.key, required this.onAccept});

  @override
  State<InterpreterAgreementsView> createState() => _InterpreterAgreementsViewState();
}

class _InterpreterAgreementsViewState extends State<InterpreterAgreementsView> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      height: 1.5,
      fontSize: AppSize.s14,
      color: ColorManager.textPrimary,
    );
    final headingStyle = textStyle?.copyWith(fontWeight: FontWeight.bold, fontSize: AppSize.s16, color: ColorManager.primary);

    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Interpreter Agreements'),
        backgroundColor: ColorManager.primary2,
        foregroundColor: ColorManager.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSize.s20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800), // Prevents wide stretching on Web
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Independent Contractor Agreement (ICA)', style: headingStyle),
                      const SizedBox(height: AppSize.s8),
                      Text(
                        'This agreement establishes your relationship with Interbridge. You are engaged as an independent contractor, not an employee. '
                        'You are solely responsible for your own taxes and are not entitled to employment benefits, health insurance, or workers\' compensation from Interbridge. '
                        'Your compensation is calculated on a per-minute or per-session basis and is distributed through our designated payment platform (e.g., Payoneer/Stripe). '
                        'Interbridge reserves the right to suspend or terminate your access for failing to meet quality standards, excessive missed calls, or violating platform policies.',
                        style: textStyle,
                      ),
                      const SizedBox(height: AppSize.s24),
                      
                      Text('2. Strict Non-Disclosure Agreement (NDA)', style: headingStyle),
                      const SizedBox(height: AppSize.s8),
                      Text(
                        'Given the sensitive nature of telehealth communications, you are strictly prohibited from:\n\n'
                        '• Recording audio or video of any session using internal software or external devices.\n'
                        '• Taking screenshots or capturing any visual data during live sessions.\n'
                        '• Discussing, sharing, or storing any medical information, patient names, diagnoses, or consultation details with anyone outside the platform.\n\n'
                        'Violation of this NDA will result in immediate termination and potential legal action.',
                        style: textStyle,
                      ),
                      const SizedBox(height: AppSize.s24),
                      
                      Text('3. HIPAA Subcontractor Business Associate Agreement (BAA)', style: headingStyle),
                      const SizedBox(height: AppSize.s8),
                      Text(
                        'As a subcontractor facilitating calls that contain Protected Health Information (PHI), you are legally bound by the Health Insurance Portability and Accountability Act (HIPAA) to uphold strict data security and privacy standards. '
                        'You must safeguard all PHI you encounter, ensure you are in a private room where no one else can hear the consultation, and immediately report any accidental data breaches or unauthorized access to Interbridge.',
                        style: textStyle,
                      ),
                      const SizedBox(height: AppSize.s40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSize.s20),
            decoration: BoxDecoration(
              color: ColorManager.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (value) {
                              setState(() {
                                _agreed = value ?? false;
                              });
                            },
                            activeColor: ColorManager.primary2,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'I have read and agree to the Independent Contractor Agreement, Non-Disclosure Agreement, and HIPAA Subcontractor BAA, and I accept full legal responsibility for my compliance.',
                                style: textStyle?.copyWith(fontSize: AppSize.s12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSize.s16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _agreed ? widget.onAccept : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorManager.primary2,
                            padding: const EdgeInsets.symmetric(vertical: AppSize.s14),
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child: const Text('Accept & Continue', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}