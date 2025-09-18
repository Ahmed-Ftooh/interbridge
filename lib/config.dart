// config.dart
// const String agoraAppId = String.fromEnvironment('AGORA_APP_ID');
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get agoraAppId {
  final appId = dotenv.env['AGORA_APP_ID'];
  if (appId == null || appId.isEmpty) {
    throw Exception(
      'AGORA_APP_ID is not set in environment variables. Please check your .env file.',
    );
  }
  return appId;
}

String get agoraAppCertificate {
  final certificate = dotenv.env['AGORA_APP_CERTIFICATE'];
  if (certificate == null || certificate.isEmpty) {
    throw Exception(
      'AGORA_APP_CERTIFICATE is not set in environment variables. Please check your .env file.',
    );
  }
  return certificate;
}
