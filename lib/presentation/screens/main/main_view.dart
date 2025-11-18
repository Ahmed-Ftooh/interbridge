import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/main/document_translation/document_translation_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_dashboard_view.dart';
import 'package:interbridge/presentation/screens/main/home/interpreter_home_view.dart';
import 'package:interbridge/presentation/screens/main/home/requester_home_view.dart';
import 'package:interbridge/presentation/screens/main/profile/profile_view.dart';
import 'package:interbridge/presentation/screens/main/setting/setting_view.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/models/user_profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interbridge/presentation/screens/main/home/bloc/interpreter_job_bloc.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/widgets/error_display_widget.dart';
import 'package:interbridge/core/error_handler.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'package:interbridge/presentation/screens/main/chat/chat_view.dart';
import 'package:interbridge/presentation/screens/main/chat/enhanced_call_view.dart';
import 'package:interbridge/presentation/screens/main/chat/bloc/chat_bloc.dart';
import 'package:interbridge/data/services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _supabaseService = instance<SupabaseService>();
    _loadUserProfile();
    _checkForActiveSession();
  }

  Future<void> _loadUserProfile() async {
    try {
      log('DEBUG: Starting to load user profile');
      final currentUser = _supabaseService.getCurrentUser();
      log('DEBUG: Current user: ${currentUser?.id}');

      if (currentUser != null) {
        log(
          'DEBUG: Attempting to get user profile for user: ${currentUser.id}',
        );
        final profile = await _supabaseService.getUserProfile(currentUser.id);
        log('DEBUG: User profile loaded: ${profile?.role}');

        if (mounted) {
          setState(() {
            userProfile = profile;
            isLoading = false;
            error = null;
            _pages = _buildPages();
          });
        }
      } else {
        log('DEBUG: No current user found');
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
      log('DEBUG: Error loading user profile: $e');
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

      // Check if the request status has changed to accepted
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

        // Update session to reflect that request was accepted
        await SessionService.saveSession(
          requestId: requestId,
          requesterId: session['requesterId'] as String,
          interpreterId: response['accepted_by'] as String,
          currentScreen: 'chat', // Move directly to chat
        );
      }

      // Automatically restore session without showing dialog
      await _restoreSession();
    } catch (e) {
      log('Error checking request status: $e');
      // If there's an error, still try to restore session
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
      final requesterId = session['requesterId'] as String;
      final interpreterId = session['interpreterId'] as String;
      final currentScreen = session['currentScreen'] as String?;

      log('Restoring session: $currentScreen for request: $requestId');

      // Don't restore if screen is 'waiting_request' - the request might have been accepted
      // The _checkIfRequestWasAccepted already handled updating the session if needed
      if (currentScreen == 'waiting_request') {
        log('Skipping restore for waiting_request - already checked status');
        return;
      }

      Widget targetScreen;

      switch (currentScreen) {
        case 'chat':
          targetScreen = BlocProvider(
            create: (_) => ChatBloc(service: instance<ChatService>()),
            child: ChatView(
              requestId: requestId,
              requesterId: requesterId,
              interpreterId: interpreterId,
            ),
          );
          break;
        case 'call':
          targetScreen = EnhancedCallScreen(channelId: requestId);
          break;
        default:
          log('Unknown screen type: $currentScreen');
          return;
      }

      if (mounted) {
        // Use pushAndRemoveUntil to make chat the main screen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => targetScreen),
          (route) => false, // Remove all previous routes
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

  List<Widget> _buildPages() {
    if (isLoading) {
      // Build lightweight placeholders while loading
      return const [
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
      ];
    }

    if (error != null) {
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
      return [errorWidget, errorWidget, errorWidget, errorWidget];
    }

    final isInterpreter = userProfile?.role == 'interpreter';
    log(
      'DEBUG: User role: ${userProfile?.role}, isInterpreter: $isInterpreter',
    );
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
      const ProfileView(),
      const SettingView(),
    ];
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined, size: 30),
        label: AppStrings.home,
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.description, size: 30),
        label: AppStrings.documentTranslation,
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person, size: 30),
        label: 'Profile',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.settings, size: 30),
        label: AppStrings.settings,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
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
          iconSize: AppSize.s24,
          selectedItemColor: ColorManager.primary2,
          unselectedItemColor: ColorManager.grey,
          currentIndex: currentIndex,
          onTap: (index) {
            if (index >= 0 && index < 4) {
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
