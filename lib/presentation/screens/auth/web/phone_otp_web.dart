import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';

/// Web phone number collection screen — Step 1 of interpreter onboarding.
/// Collects the phone number and passes it forward (admin verifies later).
class PhoneOtpWebScreen extends StatefulWidget {
  const PhoneOtpWebScreen({super.key});

  @override
  State<PhoneOtpWebScreen> createState() => _PhoneOtpWebScreenState();
}

class _PhoneOtpWebScreenState extends State<PhoneOtpWebScreen> {
  final _phoneController = TextEditingController();
  bool _isSaving = false;
  String? _selectedCountryCode = '+1';

  static const _countryCodes = [
    ('+1', '🇺🇸 US +1'),
    ('+44', '🇬🇧 UK +44'),
    ('+20', '🇪🇬 EG +20'),
    ('+971', '🇦🇪 UAE +971'),
    ('+966', '🇸🇦 SA +966'),
    ('+33', '🇫🇷 FR +33'),
    ('+49', '🇩🇪 DE +49'),
    ('+34', '🇪🇸 ES +34'),
    ('+55', '🇧🇷 BR +55'),
    ('+86', '🇨🇳 CN +86'),
    ('+91', '🇮🇳 IN +91'),
    ('+81', '🇯🇵 JP +81'),
    ('+82', '🇰🇷 KR +82'),
    ('+7', '🇷🇺 RU +7'),
    ('+52', '🇲🇽 MX +52'),
    ('+234', '🇳🇬 NG +234'),
    ('+254', '🇰🇪 KE +254'),
    ('+27', '🇿🇦 ZA +27'),
    ('+61', '🇦🇺 AU +61'),
    ('+64', '🇳🇿 NZ +64'),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber =>
      '$_selectedCountryCode${_phoneController.text.trim()}';

  Future<void> _saveAndContinue() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 7) {
      CustomSnackBar.show(
        context,
        message: 'Please enter a valid phone number',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);

    // Phone number is passed to the next screen and saved to DB during
    // the final registration step. No OTP is sent — admin verifies later.
    if (mounted) {
      setState(() => _isSaving = false);
      _continue();
    }
  }

  void _continue() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    args['phoneNumber'] = _fullPhoneNumber;
    args['phoneVerified'] = false; // admin will verify
    Navigator.of(
      context,
    ).pushNamed(Routes.governmentIdUploadRoute, arguments: args);
  }

  void _skipPhoneEntry() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    args['phoneVerified'] = false;
    Navigator.of(
      context,
    ).pushNamed(Routes.governmentIdUploadRoute, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    return AuthWebWrapper(
      title: 'Your phone number',
      subtitle: 'Add your phone number so clients and admins can reach you',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(1, 9),
          const SizedBox(height: 28),

          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF0EA5E9), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your phone number will be verified by an admin after registration.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF0C4A6E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Phone number input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country code dropdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    items:
                        _countryCodes
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.$1,
                                child: Text(
                                  c.$2,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedCountryCode = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Phone input
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B82F6),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAndContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: const Color(
                  0xFF0F172A,
                ).withValues(alpha: 0.6),
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),

          const SizedBox(height: 16),

          // Skip option
          Center(
            child: TextButton(
              onPressed: _skipPhoneEntry,
              child: const Text(
                'Skip for now',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i < current;
        final isCurrent = i == current - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color:
                  isCurrent
                      ? const Color(0xFF3B82F6)
                      : isActive
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
