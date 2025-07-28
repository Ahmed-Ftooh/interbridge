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
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Widget> get pages {
    if (isLoading) {
      return [
        const Center(child: CircularProgressIndicator()),
        const ChatView(),
        const NotificationView(),
        const SettingView(),
      ];
    }

    final isInterpreter = userProfile?.role == 'interpreter';

    if (isInterpreter) {
      return [
        const InterpreterHomeView(),
        const ChatView(),
        const NotificationView(),
        const SettingView(),
      ];
    } else {
      return [
        const RequesterHomeView(),
        const ChatView(),
        const NotificationView(),
        const SettingView(),
      ];
    }
  }

  List<String> get titles {
    if (isLoading) {
      return [
        AppStrings.home,
        AppStrings.chat,
        AppStrings.notifications,
        AppStrings.settings,
      ];
    }

    final isInterpreter = userProfile?.role == 'interpreter';

    if (isInterpreter) {
      return [
        AppStrings.home,
        AppStrings.chat,
        AppStrings.notifications,
        AppStrings.settings,
      ];
    } else {
      return [
        AppStrings.home,
        AppStrings.chat,
        AppStrings.notifications,
        AppStrings.settings,
      ];
    }
  }

  List<BottomNavigationBarItem> get navigationItems {
    if (isLoading) {
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

    final isInterpreter = userProfile?.role == 'interpreter';

    if (isInterpreter) {
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
    } else {
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
  }

  var currentIndex = 0;
  var title = 'Home';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        backgroundColor: ColorManager.primary2,
        foregroundColor: ColorManager.white,
        elevation: 0,
      ),
      body: pages[currentIndex],
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
          onTap: onTap,
          items: navigationItems,
        ),
      ),
    );
  }

  onTap(int index) {
    setState(() {
      currentIndex = index;
      title = titles[index];
    });
  }
}
