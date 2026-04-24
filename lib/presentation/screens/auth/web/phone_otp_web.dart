import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    ('+1', '🇺🇸 US/CA +1'),
    ('+7', '🇷🇺 RU +7'),
    ('+20', '🇪🇬 EG +20'),
    ('+27', '🇿🇦 ZA +27'),
    ('+30', '🇬🇷 GR +30'),
    ('+31', '🇳🇱 NL +31'),
    ('+32', '🇧🇪 BE +32'),
    ('+33', '🇫🇷 FR +33'),
    ('+34', '🇪🇸 ES +34'),
    ('+36', '🇭🇺 HU +36'),
    ('+39', '🇮🇹 IT +39'),
    ('+40', '🇷🇴 RO +40'),
    ('+41', '🇨🇭 CH +41'),
    ('+43', '🇦🇹 AT +43'),
    ('+44', '🇬🇧 UK +44'),
    ('+45', '🇩🇰 DK +45'),
    ('+46', '🇸🇪 SE +46'),
    ('+47', '🇳🇴 NO +47'),
    ('+48', '🇵🇱 PL +48'),
    ('+49', '🇩🇪 DE +49'),
    ('+51', '🇵🇪 PE +51'),
    ('+52', '🇲🇽 MX +52'),
    ('+53', '🇨🇺 CU +53'),
    ('+54', '🇦🇷 AR +54'),
    ('+55', '🇧🇷 BR +55'),
    ('+56', '🇨🇱 CL +56'),
    ('+57', '🇨🇴 CO +57'),
    ('+58', '🇻🇪 VE +58'),
    ('+60', '🇲🇾 MY +60'),
    ('+61', '🇦🇺 AU +61'),
    ('+62', '🇮🇩 ID +62'),
    ('+63', '🇵🇭 PH +63'),
    ('+64', '🇳🇿 NZ +64'),
    ('+65', '🇸🇬 SG +65'),
    ('+66', '🇹🇭 TH +66'),
    ('+81', '🇯🇵 JP +81'),
    ('+82', '🇰🇷 KR +82'),
    ('+84', '🇻🇳 VN +84'),
    ('+86', '🇨🇳 CN +86'),
    ('+90', '🇹🇷 TR +90'),
    ('+91', '🇮🇳 IN +91'),
    ('+92', '🇵🇰 PK +92'),
    ('+93', '🇦🇫 AF +93'),
    ('+94', '🇱🇰 LK +94'),
    ('+95', '🇲🇲 MM +95'),
    ('+98', '🇮🇷 IR +98'),
    ('+212', '🇲🇦 MA +212'),
    ('+213', '🇩🇿 DZ +213'),
    ('+216', '🇹🇳 TN +216'),
    ('+218', '🇱🇾 LY +218'),
    ('+220', '🇬🇲 GM +220'),
    ('+221', '🇸🇳 SN +221'),
    ('+233', '🇬🇭 GH +233'),
    ('+234', '🇳🇬 NG +234'),
    ('+249', '🇸🇩 SD +249'),
    ('+250', '🇷🇼 RW +250'),
    ('+251', '🇪🇹 ET +251'),
    ('+252', '🇸🇴 SO +252'),
    ('+253', '🇩🇯 DJ +253'),
    ('+254', '🇰🇪 KE +254'),
    ('+255', '🇹🇿 TZ +255'),
    ('+256', '🇺🇬 UG +256'),
    ('+260', '🇿🇲 ZM +260'),
    ('+263', '🇿🇼 ZW +263'),
    ('+353', '🇮🇪 IE +353'),
    ('+354', '🇮🇸 IS +354'),
    ('+358', '🇫🇮 FI +358'),
    ('+370', '🇱🇹 LT +370'),
    ('+371', '🇱🇻 LV +371'),
    ('+372', '🇪🇪 EE +372'),
    ('+380', '🇺🇦 UA +380'),
    ('+381', '🇷🇸 RS +381'),
    ('+385', '🇭🇷 HR +385'),
    ('+386', '🇸🇮 SI +386'),
    ('+420', '🇨🇿 CZ +420'),
    ('+421', '🇸🇰 SK +421'),
    ('+880', '🇧🇩 BD +880'),
    ('+960', '🇲🇻 MV +960'),
    ('+961', '🇱🇧 LB +961'),
    ('+962', '🇯🇴 JO +962'),
    ('+963', '🇸🇾 SY +963'),
    ('+964', '🇮🇶 IQ +964'),
    ('+965', '🇰🇼 KW +965'),
    ('+966', '🇸🇦 SA +966'),
    ('+967', '🇾🇪 YE +967'),
    ('+968', '🇴🇲 OM +968'),
    ('+970', '🇵🇸 PS +970'),
    ('+971', '🇦🇪 AE +971'),
    ('+972', '🇮🇱 IL +972'),
    ('+973', '🇧🇭 BH +973'),
    ('+974', '🇶🇦 QA +974'),
    ('+975', '🇧🇹 BT +975'),
    ('+976', '🇲🇳 MN +976'),
    ('+977', '🇳🇵 NP +977'),
    ('+992', '🇹🇯 TJ +992'),
    ('+993', '🇹🇲 TM +993'),
    ('+994', '🇦🇿 AZ +994'),
    ('+995', '🇬🇪 GE +995'),
    ('+996', '🇰🇬 KG +996'),
    ('+998', '🇺🇿 UZ +998'),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber =>
      '$_selectedCountryCode${_phoneController.text.trim()}';

  Future<void> _showCountryPicker() async {
    final searchController = TextEditingController();
    String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchController.text.toLowerCase();
            final filtered = _countryCodes.where((c) {
              return c.$2.toLowerCase().contains(query) || c.$1.contains(query);
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 350,
                height: 500,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Select Country Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                        hintText: 'Search country or code...',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(c.$1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    c.$2,
                                    style: const TextStyle(fontSize: 15, color: Color(0xFF334155)),
                                  ),
                                  Text(
                                    c.$1,
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      if (mounted) setState(() => _selectedCountryCode = result);
    }
  }

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

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('users_profile')
            .update({'phone_number': _fullPhoneNumber, 'phone_verified': false})
            .eq('user_id', userId);

        try {
          await Supabase.instance.client.from('phone_verifications').insert({
            'user_id': userId,
            'phone_number': _fullPhoneNumber,
            'verified': false,
            if (Supabase.instance.client.auth.currentUser?.email != null)
              'email': Supabase.instance.client.auth.currentUser!.email,
          });
        } catch (_) {
          // Keep onboarding flow moving even if this supplemental write fails.
        }

        await Supabase.instance.client
            .from('interpreter_details')
            .update({'onboarding_status': 'phone_entered'})
            .eq('user_id', userId);
      }
    } catch (e) {
      // Ignore or show error
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        _continue();
      }
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

  @override
  Widget build(BuildContext context) {
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    final fullScreenResume = routeArgs['authContinuationFullScreen'] == true;

    return AuthWebWrapper(
      fullScreen: fullScreenResume,
      title: 'Your phone number',
      subtitle: 'Add your phone number so clients and admins can reach you',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(7, 9),
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
              // Country code selector
              InkWell(
                onTap: _showCountryPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52, // Match typical TextFormField height
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedCountryCode ?? '+1',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
                    ],
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
