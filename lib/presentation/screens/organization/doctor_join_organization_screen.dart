import 'package:flutter/material.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';

class DoctorJoinOrganizationScreen extends StatefulWidget {
  const DoctorJoinOrganizationScreen({super.key});

  @override
  State<DoctorJoinOrganizationScreen> createState() =>
      _DoctorJoinOrganizationScreenState();
}

class _DoctorJoinOrganizationScreenState
    extends State<DoctorJoinOrganizationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  final _supabase = SupabaseService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  Map<String, dynamic>? _validatedInvite;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _supabase.validateInviteCode(
        _inviteCodeController.text.trim(),
      );

      if (result != null) {
        setState(() {
          _validatedInvite = result;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Invalid or expired invite code',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error validating code: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _proceedToRegistration() {
    if (_validatedInvite == null) return;

    Navigator.of(context).pushNamed(
      Routes.doctorRegisterWithInviteRoute,
      arguments: _validatedInvite,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        centerTitle: true,
        elevation: 0,
        title: Text(
          'Join Organization',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: ColorManager.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back_ios,
            color: ColorManager.white,
            size: AppSize.s24,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSize.s24),
              decoration: BoxDecoration(
                gradient: ColorManager.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppSize.s30),
                  bottomRight: Radius.circular(AppSize.s30),
                ),
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSize.s16),
                      decoration: BoxDecoration(
                        color: ColorManager.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppSize.s20),
                      ),
                      child: Icon(
                        Icons.business,
                        color: ColorManager.white,
                        size: AppSize.s40,
                      ),
                    ),
                    const SizedBox(height: AppSize.s16),
                    Text(
                      'Enter Invite Code',
                      style: TextStyle(
                        fontSize: AppSize.s24,
                        fontWeight: FontWeight.bold,
                        color: ColorManager.white,
                      ),
                    ),
                    const SizedBox(height: AppSize.s8),
                    Text(
                      'Enter the invite code provided by your organization',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppSize.s14,
                        color: ColorManager.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSize.s24),
                    child:
                        _validatedInvite == null
                            ? _buildCodeEntryForm()
                            : _buildOrganizationConfirmation(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeEntryForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Invite Code Input
          Container(
            decoration: BoxDecoration(
              color: ColorManager.backgroundCard,
              borderRadius: BorderRadius.circular(AppSize.s16),
              boxShadow: [
                BoxShadow(
                  color: ColorManager.primary2.withValues(alpha: 0.1),
                  blurRadius: AppSize.s12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: _inviteCodeController,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSize.s24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: 'XXXXXXXX',
                hintStyle: TextStyle(
                  color: ColorManager.greyMedium,
                  letterSpacing: 4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSize.s16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: ColorManager.backgroundCard,
                contentPadding: const EdgeInsets.all(AppSize.s20),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an invite code';
                }
                if (value.trim().length < 6) {
                  return 'Invite code must be at least 6 characters';
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: AppSize.s24),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 56.0,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _validateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.primary2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSize.s16),
                ),
              ),
              child:
                  _isLoading
                      ? SizedBox(
                        height: AppSize.s24,
                        width: AppSize.s24,
                        child: CircularProgressIndicator(
                          color: ColorManager.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        'Verify Code',
                        style: TextStyle(
                          fontSize: AppSize.s18,
                          fontWeight: FontWeight.bold,
                          color: ColorManager.white,
                        ),
                      ),
            ),
          ),

          const SizedBox(height: AppSize.s24),

          // Info text
          Container(
            padding: const EdgeInsets.all(AppSize.s16),
            decoration: BoxDecoration(
              color: ColorManager.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSize.s12),
              border: Border.all(
                color: ColorManager.info.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: ColorManager.info),
                const SizedBox(width: AppSize.s12),
                Expanded(
                  child: Text(
                    'Ask your organization administrator for the invite code',
                    style: TextStyle(
                      color: ColorManager.info,
                      fontSize: AppSize.s14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationConfirmation() {
    final organization =
        _validatedInvite!['organization'] as Map<String, dynamic>;
    final orgName = organization['name'] ?? 'Organization';

    return Column(
      children: [
        // Success Icon
        Container(
          padding: const EdgeInsets.all(AppSize.s20),
          decoration: BoxDecoration(
            color: ColorManager.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            color: ColorManager.success,
            size: AppSize.s60,
          ),
        ),

        const SizedBox(height: AppSize.s24),

        Text(
          'Valid Invite Code!',
          style: TextStyle(
            fontSize: AppSize.s20,
            fontWeight: FontWeight.bold,
            color: ColorManager.success,
          ),
        ),

        const SizedBox(height: AppSize.s24),

        // Organization Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSize.s24),
          decoration: BoxDecoration(
            color: ColorManager.backgroundCard,
            borderRadius: BorderRadius.circular(AppSize.s20),
            boxShadow: [
              BoxShadow(
                color: ColorManager.primary2.withValues(alpha: 0.1),
                blurRadius: AppSize.s12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSize.s16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business,
                  color: Colors.orange,
                  size: AppSize.s40,
                ),
              ),
              const SizedBox(height: AppSize.s16),
              Text(
                'You are joining',
                style: TextStyle(
                  fontSize: AppSize.s14,
                  color: ColorManager.textSecondary,
                ),
              ),
              const SizedBox(height: AppSize.s8),
              Text(
                orgName,
                style: TextStyle(
                  fontSize: AppSize.s24,
                  fontWeight: FontWeight.bold,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: AppSize.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSize.s16,
                  vertical: AppSize.s8,
                ),
                decoration: BoxDecoration(
                  color: ColorManager.primary2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSize.s20),
                ),
                child: Text(
                  'Role: Doctor',
                  style: TextStyle(
                    color: ColorManager.primary2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSize.s32),

        // Continue Button
        SizedBox(
          width: double.infinity,
          height: 56.0,
          child: ElevatedButton(
            onPressed: _proceedToRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.primary2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSize.s16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue to Registration',
                  style: TextStyle(
                    fontSize: AppSize.s18,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.white,
                  ),
                ),
                const SizedBox(width: AppSize.s8),
                Icon(Icons.arrow_forward, color: ColorManager.white),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSize.s16),

        // Try Different Code Button
        TextButton(
          onPressed: () {
            setState(() {
              _validatedInvite = null;
              _inviteCodeController.clear();
            });
          },
          child: Text(
            'Use a different code',
            style: TextStyle(color: ColorManager.primary2),
          ),
        ),
      ],
    );
  }
}
