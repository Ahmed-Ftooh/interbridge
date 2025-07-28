import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/strings_manager.dart';

class SettingView extends StatefulWidget {
  const SettingView({super.key});

  @override
  State<SettingView> createState() => _SettingViewState();
}

class _SettingViewState extends State<SettingView> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text(AppStrings.settingsScreen));
  }
}
