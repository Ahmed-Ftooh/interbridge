import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for making phone calls to patients via Twilio
class TwilioCallService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Initiate an outbound phone call to a patient
  /// Returns the call SID if successful
  Future<TwilioCallResult> initiateCall({
    required String toPhoneNumber,
    required String requestId,
  }) async {
    try {
      final callerId = _supabase.auth.currentUser?.id;
      if (callerId == null) {
        return TwilioCallResult.error('User not authenticated');
      }

      // Format phone number (ensure it has country code)
      final formattedNumber = _formatPhoneNumber(toPhoneNumber);

      log('Initiating Twilio call to $formattedNumber for request $requestId');

      final response = await _supabase.functions.invoke(
        'twilio-call',
        body: {
          'action': 'initiate',
          'toPhoneNumber': formattedNumber,
          'requestId': requestId,
          'callerId': callerId,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Unknown error';
        log('Twilio call failed: $error');
        return TwilioCallResult.error(error.toString());
      }

      final callSid = response.data?['callSid'] as String?;
      final status = response.data?['status'] as String?;

      if (callSid == null) {
        return TwilioCallResult.error('No call SID returned');
      }

      log('Twilio call initiated: $callSid, status: $status');
      return TwilioCallResult.success(
        callSid: callSid,
        status: status ?? 'initiated',
        toPhone: formattedNumber,
      );
    } catch (e) {
      log('Error initiating Twilio call: $e');
      return TwilioCallResult.error(e.toString());
    }
  }

  /// Get the current status of a phone call
  Future<TwilioCallStatus?> getCallStatus(String callSid) async {
    try {
      final response = await _supabase.functions.invoke(
        'twilio-call',
        body: {'action': 'status', 'callSid': callSid},
      );

      if (response.status != 200) {
        log('Failed to get call status: ${response.data}');
        return null;
      }

      return TwilioCallStatus(
        callSid: callSid,
        status: response.data?['status'] as String? ?? 'unknown',
      );
    } catch (e) {
      log('Error getting call status: $e');
      return null;
    }
  }

  /// End an active phone call
  Future<bool> endCall(String callSid) async {
    try {
      log('Ending Twilio call: $callSid');

      final response = await _supabase.functions.invoke(
        'twilio-call',
        body: {'action': 'end', 'callSid': callSid},
      );

      if (response.status != 200) {
        log('Failed to end call: ${response.data}');
        return false;
      }

      log('Twilio call ended successfully');
      return true;
    } catch (e) {
      log('Error ending Twilio call: $e');
      return false;
    }
  }

  /// Get call history for a specific request
  Future<List<PhoneCallRecord>> getCallHistory(String requestId) async {
    try {
      final response = await _supabase
          .from('phone_calls')
          .select()
          .eq('request_id', requestId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => PhoneCallRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('Error getting call history: $e');
      return [];
    }
  }

  /// Format phone number to E.164 format
  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // If doesn't start with +, assume US number and add +1
    if (!cleaned.startsWith('+')) {
      // Remove leading 1 if present (US country code without +)
      if (cleaned.startsWith('1') && cleaned.length == 11) {
        cleaned = '+$cleaned';
      } else if (cleaned.length == 10) {
        cleaned = '+1$cleaned';
      } else {
        // Just add + for other formats
        cleaned = '+$cleaned';
      }
    }

    return cleaned;
  }
}

/// Result of initiating a Twilio call
class TwilioCallResult {
  final bool success;
  final String? callSid;
  final String? status;
  final String? toPhone;
  final String? errorMessage;

  TwilioCallResult._({
    required this.success,
    this.callSid,
    this.status,
    this.toPhone,
    this.errorMessage,
  });

  factory TwilioCallResult.success({
    required String callSid,
    required String status,
    required String toPhone,
  }) {
    return TwilioCallResult._(
      success: true,
      callSid: callSid,
      status: status,
      toPhone: toPhone,
    );
  }

  factory TwilioCallResult.error(String message) {
    return TwilioCallResult._(success: false, errorMessage: message);
  }
}

/// Status of a Twilio call
class TwilioCallStatus {
  final String callSid;
  final String status;

  TwilioCallStatus({required this.callSid, required this.status});

  bool get isActive =>
      status == 'initiated' ||
      status == 'ringing' ||
      status == 'queued' ||
      status == 'in-progress';

  bool get isCompleted =>
      status == 'completed' ||
      status == 'failed' ||
      status == 'busy' ||
      status == 'no-answer' ||
      status == 'canceled';
}

/// Record of a phone call from database
class PhoneCallRecord {
  final String id;
  final String callSid;
  final String? requestId;
  final String? callerId;
  final String toPhone;
  final String fromPhone;
  final String status;
  final String direction;
  final int? durationSeconds;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  PhoneCallRecord({
    required this.id,
    required this.callSid,
    this.requestId,
    this.callerId,
    required this.toPhone,
    required this.fromPhone,
    required this.status,
    required this.direction,
    this.durationSeconds,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  factory PhoneCallRecord.fromJson(Map<String, dynamic> json) {
    return PhoneCallRecord(
      id: json['id'] as String,
      callSid: json['call_sid'] as String,
      requestId: json['request_id'] as String?,
      callerId: json['caller_id'] as String?,
      toPhone: json['to_phone'] as String,
      fromPhone: json['from_phone'] as String,
      status: json['status'] as String,
      direction: json['direction'] as String,
      durationSeconds: json['duration_seconds'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      answeredAt:
          json['answered_at'] != null
              ? DateTime.parse(json['answered_at'] as String)
              : null,
      endedAt:
          json['ended_at'] != null
              ? DateTime.parse(json['ended_at'] as String)
              : null,
    );
  }

  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
