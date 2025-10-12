import 'package:flutter/material.dart';
import 'package:interbridge/data/services/session_service.dart';
import 'dart:developer';

class SessionRestorationWidget extends StatefulWidget {
  final Widget child;

  const SessionRestorationWidget({super.key, required this.child});

  @override
  State<SessionRestorationWidget> createState() =>
      _SessionRestorationWidgetState();
}

class _SessionRestorationWidgetState extends State<SessionRestorationWidget>
    with WidgetsBindingObserver {
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForActiveSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log('App lifecycle state changed: $state');
  }

  Future<void> _checkForActiveSession() async {
    try {
      final hasSession = await SessionService.hasActiveSession();

      setState(() {
        _isCheckingSession = false;
      });

      if (hasSession) {
        log('Active session found - user will be prompted to restore');
      } else {
        log('No active session found');
      }
    } catch (e) {
      log('Error checking session: $e');
      setState(() {
        _isCheckingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking for active session...'),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
