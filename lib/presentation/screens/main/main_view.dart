import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';
import 'package:interbridge/presentation/screens/main/chat/chat_view.dart';
import 'package:interbridge/presentation/screens/main/home/interpreter_home_view.dart';
import 'package:interbridge/presentation/screens/main/home/requester_home_view.dart';
import 'package:interbridge/presentation/screens/main/notification/notification_view.dart';
import 'package:interbridge/presentation/screens/main/setting/setting_view.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/models/user_profile.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  UserProfile? userProfile;
  bool isLoading = true;
  String? errorMessage;
  final SupabaseService _supabaseService = SupabaseService();
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
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
            errorMessage = null;
          });
        }
      } else {
        log('DEBUG: No current user found');
        if (mounted) {
          setState(() {
            isLoading = false;
            errorMessage = 'No user found. Please log in again.';
          });
        }
      }
    } catch (e) {
      log('DEBUG: Error loading user profile: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load user profile: $e';
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

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ColorManager.error),
            const SizedBox(height: 16),
            Text(
              'Error Loading Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColorManager.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: ColorManager.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _loadUserProfile();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final isInterpreter = userProfile?.role == 'interpreter';
    log(
      'DEBUG: User role: ${userProfile?.role}, isInterpreter: $isInterpreter',
    );

    switch (currentIndex) {
      case 0:
        return isInterpreter
            ? const InterpreterHomeView()
            : const RequesterHomeView();
      case 1:
        return const ChatView();
      case 2:
        return const NotificationView();
      case 3:
        return const SettingView();
      default:
        return isInterpreter
            ? const InterpreterHomeView()
            : const RequesterHomeView();
    }
  }

  String _getCurrentTitle() {
    if (isLoading || errorMessage != null) {
      return AppStrings.home;
    }

    switch (currentIndex) {
      case 0:
        return AppStrings.home;
      case 1:
        return AppStrings.chat;
      case 2:
        return AppStrings.notifications;
      case 3:
        return AppStrings.settings;
      default:
        return AppStrings.home;
    }
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined, size: 30),
        label: AppStrings.home,
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.chat, size: 30),
        label: AppStrings.chat,
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.notifications, size: 30),
        label: AppStrings.notifications,
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
      appBar: AppBar(
        title: Text(
          _getCurrentTitle(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        backgroundColor: ColorManager.primary2,
        foregroundColor: ColorManager.white,
        elevation: 0,
      ),
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
