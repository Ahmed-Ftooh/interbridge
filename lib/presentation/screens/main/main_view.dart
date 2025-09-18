import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/main/document_translation/document_translation_view.dart';
import 'package:interbridge/presentation/screens/main/document_translation/interpreter_document_view.dart';
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

  @override
  void initState() {
    super.initState();
    _supabaseService = instance<SupabaseService>();
    _loadUserProfile();
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
          });
        }
      }
    } catch (e) {
      log('DEBUG: Error loading user profile: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          error = ErrorHandler.handleError(e, context: 'LoadUserProfile');
        });
      }
    }
  }

  Widget _buildCurrentPage() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your profile...'),
          ],
        ),
      );
    }

    if (error != null) {
      return ErrorDisplayWidget(
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
    }

    final isInterpreter = userProfile?.role == 'interpreter';
    log(
      'DEBUG: User role: ${userProfile?.role}, isInterpreter: $isInterpreter',
    );

    switch (currentIndex) {
      case 0:
        return isInterpreter
            ? BlocProvider(
              create: (context) => instance<InterpreterJobBloc>(),
              child: const InterpreterHomeView(),
            )
            : const RequesterHomeView();
      case 1:
        return isInterpreter
            ? const InterpreterDocumentView()
            : const DocumentTranslationView();
      case 2:
        return const ProfileView();
      case 3:
        return const SettingView();
      default:
        return isInterpreter
            ? const InterpreterHomeView()
            : const RequesterHomeView();
    }
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
      body: _buildCurrentPage(),
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
