import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/widgets/customButtom.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'dart:convert';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/models/interpreter_details.dart';
import 'package:interbridge/data/models/interpreter_language.dart';
import 'package:interbridge/data/models/interpreter_skill.dart';
import 'package:interbridge/data/models/interpreter_specialization.dart';

class EmailVerificationView extends StatefulWidget {
  const EmailVerificationView({super.key});

  @override
  State<EmailVerificationView> createState() => _EmailVerificationViewState();
}

class _EmailVerificationViewState extends State<EmailVerificationView> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;

  Future<void> _verify() async {
    var email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      // fallback to pending registration email
      final prefs = instance<AppPreferences>();
      final pendingStr = prefs.getPendingRegistration();
      if (pendingStr != null && pendingStr.isNotEmpty) {
        try {
          final data = jsonDecode(pendingStr) as Map<String, dynamic>;
          final storedEmail = data['email']?.toString();
          if (storedEmail != null && storedEmail.isNotEmpty) {
            email = storedEmail;
          }
        } catch (_) {}
      }
    }
    if (email == null || email.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'No email found in session',
        type: SnackBarType.error,
      );
      return;
    }
    if (_codeController.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Enter the verification code',
        type: SnackBarType.error,
      );
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await SupabaseService().verifyEmailOtp(
        email: email,
        token: _codeController.text.trim(),
      );
      // After verification, write pending registration to DB
      final prefs = instance<AppPreferences>();
      final pendingStr = prefs.getPendingRegistration();
      if (pendingStr != null && pendingStr.isNotEmpty) {
        final data = jsonDecode(pendingStr) as Map<String, dynamic>;
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final role = (data['role'] as String?) ?? 'requester';
          final username = (data['username'] as String?) ?? '';
          final profile = UserProfile(
            id: userId,
            role: role,
            username: username,
            profileImage: data['profileImage'],
            gender: data['gender'],
          );
          await SupabaseService().createUserProfileAfterSignUp(profile);

          if (role == 'interpreter') {
            try {
              await SupabaseService().createInterpreterDetails(
                InterpreterDetails(userId: userId),
              );
            } catch (_) {}

            final langs = (data['languages'] as List?)?.cast<String>() ?? [];
            final fluencyMapRaw = data['fluency'];
            final Map<String, dynamic> fluencyMap =
                fluencyMapRaw is Map
                    ? fluencyMapRaw.map((k, v) => MapEntry(k.toString(), v))
                    : {};
            for (final langIdStr in langs) {
              final languageId = int.tryParse(langIdStr);
              if (languageId == null || languageId <= 0) continue;
              final fluencyName = fluencyMap[langIdStr]?.toString();
              final fluencyId = _mapFluencyNameToId(fluencyName);
              await SupabaseService().addInterpreterLanguage(
                InterpreterLanguage(
                  userId: userId,
                  languageId: languageId,
                  fluencyId: fluencyId,
                ),
              );
            }

            final skills = (data['skillIds'] as List?)?.cast<int>() ?? [];
            for (final sid in skills) {
              if (sid <= 0) continue;
              await SupabaseService().addInterpreterSkill(
                InterpreterSkill(userId: userId, skillId: sid),
              );
            }

            final specs =
                (data['specializationIds'] as List?)?.cast<int>() ?? [];
            for (final sp in specs) {
              if (sp <= 0) continue;
              await SupabaseService().addInterpreterSpecialization(
                InterpreterSpecialization(userId: userId, specializationId: sp),
              );
            }

            final voiceUrl = data['voiceSampleUrl'] as String?;
            final certUrl = data['certificateUrl'] as String?;
            if (voiceUrl != null || certUrl != null) {
              await SupabaseService().updateInterpreterDetailsWithUrls(
                userId,
                voiceSampleUrl: voiceUrl,
                certificateUrl: certUrl,
              );
            }
          }
        }
        await prefs.clearPendingRegistration();
        await prefs.setLoginViewed();
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(Routes.mainRoute, (route) => false);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Verification failed: $e',
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  int _mapFluencyNameToId(String? name) {
    switch (name) {
      case 'Beginner':
        return 1;
      case 'Intermediate':
        return 2;
      case 'Upper Intermediate':
        return 3;
      case 'Native Or Fluent':
        return 4;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    String shownEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
    if (shownEmail.isEmpty) {
      final prefs = instance<AppPreferences>();
      final pendingStr = prefs.getPendingRegistration();
      if (pendingStr != null && pendingStr.isNotEmpty) {
        try {
          final data = jsonDecode(pendingStr) as Map<String, dynamic>;
          shownEmail = data['email']?.toString() ?? '';
        } catch (_) {}
      }
    }
    return Scaffold(
      backgroundColor: ColorManager.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: ColorManager.primary2,
        centerTitle: true,
        elevation: 0,
        title: const Text('Verify your email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSize.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSize.s24),
            Text(
              'We sent a verification code to:\n$shownEmail',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSize.s24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Verification code'),
            ),
            const SizedBox(height: AppSize.s16),
            CustomButton(
              onTap: _verify,
              isLoading: _isVerifying,
              color: ColorManager.primary2,
              borderRadius: BorderRadius.circular(AppSize.s12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, size: AppSize.s20),
                  SizedBox(width: AppSize.s8),
                  Text('Verify'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
