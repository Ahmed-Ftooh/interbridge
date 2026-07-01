import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/data/models/interpreter_level.dart';
import 'package:interbridge/data/models/interpreter_track.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_palette.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';
import 'package:interbridge/presentation/widgets/custom_snackbar.dart';

/// Invisible routing screen that automatically enrolls the user 
/// into the experienced track without showing them a selection UI.
class InterpreterTrackSelectionWebScreen extends StatefulWidget {
  const InterpreterTrackSelectionWebScreen({super.key});

  @override
  State<InterpreterTrackSelectionWebScreen> createState() =>
      _InterpreterTrackSelectionWebScreenState();
}

class _InterpreterTrackSelectionWebScreenState
    extends State<InterpreterTrackSelectionWebScreen> {
  bool _autoContinueTriggered = false;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == null) {
        // Safe fallback for browser refresh
        Navigator.of(context).pushReplacementNamed(
          Routes.interpreterPortalDashboardRoute,
        );
        return;
      }
      if (_autoContinueTriggered) return;
      _autoContinueTriggered = true;
      _autoEnrollAndContinue();
    });
  }

  Future<void> _autoEnrollAndContinue() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        CustomSnackBar.show(
          context,
          message: 'Error: You must be logged in to continue.',
          type: SnackBarType.error,
        );
        return;
      }

      // Automatically assign the experienced/paid track
      const selectedLevel = InterpreterLevel.paid;
      const track = InterpreterTrack.paid;

      // Update profile
      await Supabase.instance.client
          .from('users_profile')
          .update({
            'role': 'interpreter',
            'employment_type': track.name,
          })
          .eq('user_id', userId);

      // Upsert interpreter details
      await Supabase.instance.client.from('interpreter_details').upsert({
        'user_id': userId,
        'onboarding_status': 'track_selected',
        'employment_type': track.name,
      }, onConflict: 'user_id');

      if (!mounted) return;

      final currentArgs =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};
      
      final args = <String, dynamic>{
        ...currentArgs,
        'role': 'interpreter',
        'interpreterLevel': selectedLevel.name,
        'interpreterTrack': track.name,
        'requiresMedicalDocs': true,
      };

      // Push to languages invisibly
      Navigator.of(context).pushReplacementNamed(Routes.selectLanguage, arguments: args);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to configure account: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shows a clean wrapper with a spinner while it does the DB updates
    return const AuthWebWrapper(
      title: 'Preparing your workspace...',
      subtitle: 'Setting up your professional interpreter profile.',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            color: AuthWebPalette.primary,
          ),
        ),
      ),
    );
  }
}