import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interbridge/data/services/twilio_call_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';

/// Widget to make phone calls to patients during a call session
class PatientPhoneCallWidget extends StatefulWidget {
  final String requestId;
  final String? patientPhoneNumber;
  final VoidCallback? onCallStarted;
  final VoidCallback? onCallEnded;

  const PatientPhoneCallWidget({
    super.key,
    required this.requestId,
    this.patientPhoneNumber,
    this.onCallStarted,
    this.onCallEnded,
  });

  @override
  State<PatientPhoneCallWidget> createState() => _PatientPhoneCallWidgetState();
}

class _PatientPhoneCallWidgetState extends State<PatientPhoneCallWidget> {
  final TwilioCallService _twilioService = TwilioCallService();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _activeCallSid;
  String _callStatus = '';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    if (widget.patientPhoneNumber != null) {
      _phoneController.text = widget.patientPhoneNumber!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiateCall() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      _showError('Please enter a phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _callStatus = 'Initiating call...';
    });

    final result = await _twilioService.initiateCall(
      toPhoneNumber: phoneNumber,
      requestId: widget.requestId,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _activeCallSid = result.callSid;
        _callStatus = 'Calling ${result.toPhone}...';
        _isLoading = false;
      });

      widget.onCallStarted?.call();
      _startStatusPolling();
    } else {
      setState(() {
        _isLoading = false;
        _callStatus = '';
      });
      _showError(result.errorMessage ?? 'Failed to initiate call');
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_activeCallSid == null) {
        _statusTimer?.cancel();
        return;
      }

      final status = await _twilioService.getCallStatus(_activeCallSid!);
      if (!mounted) return;

      if (status != null) {
        setState(() {
          _callStatus = _getStatusMessage(status.status);
        });

        if (status.isCompleted) {
          _handleCallEnded(status.status);
        }
      }
    });
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'queued':
        return 'Call queued...';
      case 'initiated':
        return 'Initiating call...';
      case 'ringing':
        return 'Ringing...';
      case 'in-progress':
        return 'Connected';
      case 'completed':
        return 'Call ended';
      case 'busy':
        return 'Line busy';
      case 'no-answer':
        return 'No answer';
      case 'failed':
        return 'Call failed';
      case 'canceled':
        return 'Call canceled';
      default:
        return status;
    }
  }

  void _handleCallEnded(String reason) {
    _statusTimer?.cancel();
    setState(() {
      _activeCallSid = null;
      _callStatus = '';
    });
    widget.onCallEnded?.call();

    if (reason != 'completed') {
      _showError('Call ended: $reason');
    }
  }

  Future<void> _endCall() async {
    if (_activeCallSid == null) return;

    setState(() => _isLoading = true);

    final success = await _twilioService.endCall(_activeCallSid!);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      _handleCallEnded('completed');
    } else {
      _showError('Failed to end call');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showPhoneDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Third Party'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+1 (555) 123-4567',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the patient\'s phone number to add them to the call.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _initiateCall();
                },
                icon: const Icon(Icons.call),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveCall = _activeCallSid != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Call status indicator
        if (_callStatus.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color:
                  hasActiveCall
                      ? (_callStatus == 'Connected'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2))
                      : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_callStatus == 'Connected')
                  const Icon(Icons.phone_in_talk, color: Colors.green, size: 16)
                else if (hasActiveCall)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Text(
                  _callStatus,
                  style: TextStyle(
                    color:
                        _callStatus == 'Connected'
                            ? Colors.green
                            : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Call button
        if (_isLoading)
          const CircularProgressIndicator()
        else if (hasActiveCall)
          FloatingActionButton(
            onPressed: _endCall,
            backgroundColor: Colors.red,
            heroTag: 'end_third_party_call',
            child: const Icon(Icons.call_end, color: Colors.white),
          )
        else
          FloatingActionButton(
            onPressed: _showPhoneDialog,
            backgroundColor: ColorManager.primary,
            heroTag: 'add_third_party',
            child: const Icon(Icons.add_call, color: Colors.white),
          ),
      ],
    );
  }
}

/// Compact button version for adding to call controls
class CallPatientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isActive;

  const CallPatientButton({
    super.key,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          isActive ? Icons.phone_in_talk : Icons.add_call,
          color: Colors.white,
          size: 28,
        ),
        tooltip: isActive ? 'Third Party Connected' : 'Add Third Party',
      ),
    );
  }
}
