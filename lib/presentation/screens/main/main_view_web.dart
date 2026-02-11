import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/document_translation_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_dashboard_view.dart';
import 'package:interbridge/presentation/screens/main/home/bloc/interpreter_job_bloc.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_bloc.dart';
import 'package:interbridge/presentation/screens/main/profile/profile_view.dart';
import 'package:interbridge/presentation/screens/main/profile/profile_view_web.dart';
import 'package:interbridge/presentation/screens/main/profile/requester/requester_profile_bloc.dart';
import 'package:interbridge/presentation/screens/main/profile/requester/requester_profile_view.dart';
import 'package:interbridge/presentation/screens/main/profile/requester/requester_profile_view_web.dart';
import 'package:interbridge/presentation/screens/main/setting/setting_view.dart';
import 'package:interbridge/presentation/screens/main/setting/setting_view_web.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';
import 'package:interbridge/presentation/widgets/web/web_layout_shell.dart';
import 'package:interbridge/presentation/screens/main/home/web/requester_home_web.dart';
import 'package:interbridge/presentation/screens/main/home/web/interpreter_home_web.dart';
import 'package:interbridge/admin/screens/admin_list_screen.dart';
import 'package:lottie/lottie.dart';

/// Web-specific main view with modern sidebar navigation
class MainViewWeb extends StatefulWidget {
  const MainViewWeb({super.key});

  @override
  State<MainViewWeb> createState() => _MainViewWebState();
}

class _MainViewWebState extends State<MainViewWeb> {
  UserProfile? userProfile;
  bool isLoading = true;
  AppError? error;
  late final SupabaseService _supabaseService;
  int currentIndex = 0;
  List<Widget>? _pages;

  bool get _isAdmin =>
      userProfile?.role == 'admin' || userProfile?.role == 'superadmin';

  @override
  void initState() {
    super.initState();
    _supabaseService = instance<SupabaseService>();
    _loadUserProfile();
    _checkForActiveSession();
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUser = _supabaseService.getCurrentUser();

      if (currentUser != null) {
        final profile = await _supabaseService.getUserProfile(currentUser.id);

        if (mounted) {
          setState(() {
            userProfile = profile;
            isLoading = false;
            error = null;
            _pages = _buildPages();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
            error = AppError(
              message: 'No user found',
              type: ErrorType.authentication,
              userAction: 'Please log in again.',
              isRetryable: false,
            );
            _pages = _buildPages();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = ErrorHandler.handleError(e, context: 'LoadUserProfile');
          _pages = _buildPages();
        });
      }
    }
  }

  Future<void> _checkForActiveSession() async {
    try {
      final hasSession = await SessionService.hasActiveSession();

      if (hasSession) {
        log('Active session found, checking if request was accepted...');
        await _checkIfRequestWasAccepted();
      }
    } catch (e) {
      log('Error checking for active session: $e');
    }
  }

  Future<void> _checkIfRequestWasAccepted() async {
    try {
      final session = await SessionService.getSession();
      if (session == null) return;

      final requestId = session['requestId'] as String;

      final response =
          await Supabase.instance.client
              .from('interpreter_requests')
              .select('status, accepted_by, accepted_at')
              .eq('id', requestId)
              .single();

      if (response['status'] == 'accepted') {
        log(
          'Request was accepted while app was in background, updating session...',
        );

        await SessionService.saveSession(
          requestId: requestId,
          requesterId: session['requesterId'] as String,
          interpreterId: response['accepted_by'] as String,
          currentScreen: 'call',
        );
      }

      await _restoreSession();
    } catch (e) {
      log('Error checking request status: $e');
      await _restoreSession();
    }
  }

  Future<void> _restoreSession() async {
    try {
      final session = await SessionService.getSession();

      if (session == null) {
        log('No session data found');
        return;
      }

      final requestId = session['requestId'] as String;
      final currentScreen = session['currentScreen'] as String?;

      log('Restoring session: $currentScreen for request: $requestId');

      if (currentScreen == 'waiting_request') {
        log('Skipping restore for waiting_request - already checked status');
        return;
      }

      Widget targetScreen;

      switch (currentScreen) {
        case 'call':
        case 'chat':
          targetScreen = EnhancedCallScreen(channelId: requestId);
          break;
        default:
          log('Unknown screen type: $currentScreen');
          return;
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => targetScreen),
          (route) => false,
        );
      }
    } catch (e) {
      log('Error restoring session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAuthErrorWidget() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.asset(
                'assets/json/erorr.json',
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Not Logged In',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please log in to continue using Interbridge.',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    Routes.loginRoute,
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0955FA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Go to Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages() {
    if (isLoading) {
      return const [
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
      ];
    }

    if (error != null) {
      if (error!.type == ErrorType.authentication) {
        final authErrorWidget = _buildAuthErrorWidget();
        return [
          authErrorWidget,
          authErrorWidget,
          authErrorWidget,
          authErrorWidget,
        ];
      }

      final errorWidget = ErrorDisplayWidget(
        error: error!,
        onRetry:
            error!.isRetryable
                ? () {
                  setState(() {
                    isLoading = true;
                    error = null;
                  });
                  _loadUserProfile();
                }
                : null,
        title: 'Failed to load profile',
      );
      return [errorWidget, errorWidget, errorWidget, errorWidget];
    }

    final isInterpreter = userProfile?.role == 'interpreter';

    return [
      // Dashboard / Home - Web-specific views
      if (isInterpreter)
        BlocProvider(
          key: const PageStorageKey('interpreter_home_bloc_holder'),
          create: (context) => instance<InterpreterJobBloc>(),
          child: const InterpreterHomeWeb(),
        )
      else
        const RequesterHomeWeb(),
      // Documents
      if (isInterpreter)
        const InterpreterDashboardView()
      else
        const DocumentTranslationView(),
      // Profile
      if (isInterpreter)
        BlocProvider(
          key: const PageStorageKey('profile_bloc_holder'),
          create: (context) => instance<ProfileBloc>(),
          child: const ProfileViewWeb(),
        )
      else
        BlocProvider(
          key: const PageStorageKey('requester_profile_bloc_holder'),
          create: (context) => instance<RequesterProfileBloc>(),
          child: const RequesterProfileViewWeb(),
        ),
      // Settings
      const SettingViewWeb(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.translate,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0955FA)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAdmin) {
      if (error != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Admin')),
          body: ErrorDisplayWidget(
            error: error!,
            onRetry:
                error!.isRetryable
                    ? () {
                      setState(() {
                        isLoading = true;
                        error = null;
                      });
                      _loadUserProfile();
                    }
                    : null,
            title: 'Failed to load profile',
          ),
        );
      }
      return const AdminListScreen();
    }

    final pages = _pages ?? _buildPages();

    return WebLayoutShell(
      currentIndex: currentIndex,
      onNavigationChanged: (index) {
        if (index >= 0 && index < 4) {
          setState(() {
            currentIndex = index;
          });
        }
      },
      userName: userProfile?.username,
      userRole: userProfile?.role,
      userAvatar: userProfile?.profileImage,
      child: IndexedStack(index: currentIndex, children: pages),
    );
  }
}
