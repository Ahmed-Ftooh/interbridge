import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/main/document_translation/document_translation_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_dashboard_view.dart';
import 'package:interbridge/presentation/screens/main/home/interpreter_home_view.dart';
import 'package:interbridge/presentation/screens/main/home/requester_home_view.dart';
import 'package:interbridge/presentation/screens/main/profile/profile_view.dart';
import 'package:interbridge/presentation/screens/main/profile/bloc/profile_bloc.dart';
import 'package:interbridge/presentation/screens/main/profile/requester/requester_profile_view.dart';
import 'package:interbridge/presentation/screens/main/profile/requester/requester_profile_bloc.dart';
import 'package:interbridge/presentation/screens/main/setting/setting_view.dart';
import 'package:interbridge/presentation/screens/interpreter/interpreter_badges_view.dart';
import 'package:interbridge/admin/screens/admin_list_screen.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/main/home/bloc/interpreter_job_bloc.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/core/uid_utils.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/call_bloc.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  UserProfile? userProfile;
  bool isLoading = true;
  AppError? error;
  late final SupabaseService _supabaseService;
  int currentIndex = 0;
  List<Widget>? _pages; // Keep tab pages alive

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
              .select(
                'status, accepted_by, requester_id, call_type, accepted_at',
              )
              .eq('id', requestId)
              .single();

      final dbStatus = response['status'] as String?;
      final acceptedBy = response['accepted_by'] as String?;
      if (dbStatus != 'accepted' || acceptedBy == null || acceptedBy.isEmpty) {
        // Call is no longer active — discard stale session
        log(
          'Session request $requestId is not restorable (status=$dbStatus, accepted_by=$acceptedBy) — clearing stale session',
        );
        await SessionService.clearSession();
        return;
      }

      final sessionCallDataRaw = session['callData'];
      final sessionCallData =
          sessionCallDataRaw is Map
              ? Map<String, dynamic>.from(sessionCallDataRaw)
              : <String, dynamic>{};
      final remoteJoined = sessionCallData['remote_joined'] == true;

      if (!remoteJoined) {
        final waitingStartedAtRaw =
            sessionCallData['waiting_started_at']?.toString();
        final waitingStartedAt =
            waitingStartedAtRaw == null
                ? null
                : DateTime.tryParse(waitingStartedAtRaw)?.toUtc();

        final acceptedAtRaw = response['accepted_at']?.toString();
        final acceptedAt =
            acceptedAtRaw == null
                ? null
                : DateTime.tryParse(acceptedAtRaw)?.toUtc();

        final staleAnchor = waitingStartedAt ?? acceptedAt;
        if (staleAnchor != null &&
            DateTime.now().toUtc().difference(staleAnchor) >
                const Duration(seconds: 40)) {
          log(
            'Session request $requestId timed out waiting for remote join — clearing stale session',
          );
          await SessionService.clearSession();
          return;
        }
      }

      // Call is still in-progress — refresh session data and restore
      await SessionService.saveSession(
        requestId: requestId,
        requesterId: response['requester_id'] as String,
        interpreterId: acceptedBy,
        currentScreen: 'call',
        callData: {
          'call_type': response['call_type'] ?? 'voice',
          'accepted_at': response['accepted_at']?.toString(),
          'waiting_started_at':
              sessionCallData['waiting_started_at']?.toString() ??
              DateTime.now().toIso8601String(),
          'remote_joined': remoteJoined,
        },
      );

      await _restoreSession();
    } catch (e) {
      log('Error checking request status: $e — clearing stale session');
      await SessionService.clearSession();
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

      if (currentScreen == 'call' || currentScreen == 'chat') {
        if (!mounted) return;

        // Compute stable Agora UID from the current authenticated user's UUID
        final currentUserId =
            Supabase.instance.client.auth.currentUser?.id ?? '';
        final localUid = uidFromUuid(currentUserId);

        final callData = session['callData'] as Map<String, dynamic>? ?? {};
        final isVideoCall = callData['call_type'] == 'video';

        // Dispatch StartCall so Agora re-joins the channel
        context.read<CallBloc>().add(
          StartCall(
            channelId: requestId,
            localUid: localUid,
            isVideoCall: isVideoCall,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (_) => EnhancedCallScreen(
                  channelId: requestId,
                  isVideoCall: isVideoCall,
                ),
          ),
          (route) => false,
        );
      } else {
        log('Unknown screen type: $currentScreen');
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
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: AppSize.s120,
              height: AppSize.s120,
              child: Lottie.asset(
                'assets/json/erorr.json',
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
              ),
            ),
            const SizedBox(height: AppSize.s24),
            Text(
              'Not Logged In',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: ColorManager.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSize.s8),
            Text(
              'Please log in to continue using the app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColorManager.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSize.s24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);
              },
              icon: const Icon(Icons.login),
              label: const Text('Go to Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.primary,
                foregroundColor: ColorManager.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSize.s24,
                  vertical: AppSize.s12,
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
      // Build lightweight placeholders while loading
      return const [
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
      ];
    }

    if (error != null) {
      // For authentication errors, show a login button
      if (error!.type == ErrorType.authentication) {
        final authErrorWidget = _buildAuthErrorWidget();
        return [
          authErrorWidget,
          authErrorWidget,
          authErrorWidget,
          authErrorWidget,
          authErrorWidget,
        ];
      }

      // Show the same error page for all indices
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
      return [errorWidget, errorWidget, errorWidget, errorWidget, errorWidget];
    }

    final isInterpreter = userProfile?.role == 'interpreter';

    return [
      if (isInterpreter)
        BlocProvider(
          key: const PageStorageKey('interpreter_home_bloc_holder'),
          create: (context) => instance<InterpreterJobBloc>(),
          child: const InterpreterHomeView(),
        )
      else
        const RequesterHomeView(),
      if (isInterpreter)
        const InterpreterDashboardView()
      else
        const DocumentTranslationView(),
      // Use different profile views based on user role
      if (isInterpreter)
        BlocProvider(
          key: const PageStorageKey('profile_bloc_holder'),
          create: (context) => instance<ProfileBloc>(),
          child: const ProfileView(),
        )
      else
        BlocProvider(
          key: const PageStorageKey('requester_profile_bloc_holder'),
          create: (context) => instance<RequesterProfileBloc>(),
          child: const RequesterProfileView(),
        ),
      if (isInterpreter)
        const InterpreterBadgesView(),
      const SettingView(),
    ];
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    final isInterpreter = userProfile?.role == 'interpreter';
    
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined, size: 30),
        label: AppStrings.home,
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.description, size: 30),
        label: AppStrings.documentTranslation,
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person, size: 30),
        label: 'Profile',
      ),
      if (isInterpreter)
        const BottomNavigationBarItem(
          icon: Icon(Icons.workspace_premium, size: 30),
          label: 'Badges',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings, size: 30),
        label: AppStrings.settings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

    return Scaffold(
      body: Builder(
        builder: (_) {
          final pages = _pages ?? _buildPages();
          // Keep tabs alive and preserve state
          return IndexedStack(index: currentIndex, children: pages);
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: ColorManager.grey, spreadRadius: AppSize.s1),
          ],
        ),
        child: BottomNavigationBar(
          elevation: AppSize.s0,
          type: BottomNavigationBarType.fixed,
          iconSize: AppSize.s24,
          selectedItemColor: ColorManager.primary2,
          unselectedItemColor: ColorManager.grey,
          currentIndex: currentIndex,
          onTap: (index) {
            final isInterpreter = userProfile?.role == 'interpreter';
            final maxTabs = isInterpreter ? 5 : 4;
            if (index >= 0 && index < maxTabs) {
              setState(() {
                currentIndex = index;
              });
            }
          },
          items: _getNavigationItems(),
        ),
      ),
    );
  }
}
