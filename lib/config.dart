// config.dart
// const String agoraAppId = String.fromEnvironment('AGORA_APP_ID');
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get agoraAppId {
  final appId = dotenv.env['AGORA_APP_ID'];
  if (appId == null || appId.isEmpty) {
    // Return a placeholder to prevent crashes during development
    // This should be caught by the app initializer validation
    return 'PLACEHOLDER_AGORA_APP_ID';
  }
  return appId;
}

/// Check if Agora is properly configured
bool get isAgoraConfigured {
  final appId = dotenv.env['AGORA_APP_ID'];
  return appId != null && appId.isNotEmpty && appId != 'your_agora_app_id_here';
}

String get agoraAppCertificate {
  final certificate = dotenv.env['AGORA_APP_CERTIFICATE'];
  if (certificate == null || certificate.isEmpty) {
    // Return a placeholder to prevent crashes during development
    // This should be caught by the app initializer validation
    return 'PLACEHOLDER_AGORA_APP_CERTIFICATE';
  }
  return certificate;
}

String get twilioPhoneNumber {
  return dotenv.env['TWILIO_PHONE_NUMBER'] ?? '';
}

/// Stripe publishable key (test mode)
String get stripePublishableKey {
  return dotenv.env['STRIPEPUBLISHABLEKEY'] ?? '';
}

/// Check if Stripe is properly configured
bool get isStripeConfigured {
  final key = dotenv.env['STRIPEPUBLISHABLEKEY'];
  return key != null && key.isNotEmpty && key.startsWith('pk_');
}
