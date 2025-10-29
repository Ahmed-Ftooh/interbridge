import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:interbridge/core/language_mapping_utility.dart';

/// Simple machine translation service with pluggable providers.
/// Supports Google Translate API and Azure Translator if configured via env.
class MachineTranslationService {
  static final MachineTranslationService _instance =
      MachineTranslationService._internal();
  factory MachineTranslationService() => _instance;
  MachineTranslationService._internal();

  Future<String> translateText({
    required String text,
    String? fromLanguageName, // pass null to auto-detect when supported
    required String toLanguageName,
  }) async {
    final provider = dotenv.env['TRANSLATOR_PROVIDER']?.toLowerCase();
    try {
      if (provider == 'google') {
        return _translateWithGoogle(
          text: text,
          fromLanguageName: fromLanguageName,
          toLanguageName: toLanguageName,
        );
      }
      if (provider == 'azure') {
        return _translateWithAzure(
          text: text,
          fromLanguageName: fromLanguageName,
          toLanguageName: toLanguageName,
        );
      }

      // Fallback: echo text and log missing config to avoid crashes during dev.
      log(
        'MachineTranslationService not configured. Set TRANSLATOR_PROVIDER with keys.',
      );
      return text;
    } catch (e) {
      log('Machine translation failed: $e');
      rethrow;
    }
  }

  // Google Translate v2 REST API
  Future<String> _translateWithGoogle({
    required String text,
    String? fromLanguageName,
    required String toLanguageName,
  }) async {
    final key = dotenv.env['GOOGLE_TRANSLATE_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_TRANSLATE_API_KEY is not set');
    }
    final target = _toIsoCode(toLanguageName);
    final source =
        fromLanguageName != null
            ? _toIsoCode(fromLanguageName)
            : null; // null => auto

    final uri = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2',
    );
    final body = <String, String>{
      'q': text,
      'target': target,
      if (source != null) 'source': source,
      'format': 'text',
      'key': key,
    };

    final resp = await http.post(uri, body: body);
    if (resp.statusCode != 200) {
      throw Exception(
        'Google Translate error ${resp.statusCode}: ${resp.body}',
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final translations = (data['data']?['translations'] as List?) ?? const [];
    if (translations.isEmpty) {
      throw Exception('No translation returned');
    }
    return translations.first['translatedText'] as String;
  }

  // Azure Translator
  Future<String> _translateWithAzure({
    required String text,
    String? fromLanguageName,
    required String toLanguageName,
  }) async {
    final key = dotenv.env['AZURE_TRANSLATOR_KEY'];
    final region = dotenv.env['AZURE_TRANSLATOR_REGION'];
    if (key == null || key.isEmpty || region == null || region.isEmpty) {
      throw Exception('AZURE_TRANSLATOR_KEY/REGION not set');
    }
    final target = _toIsoCode(toLanguageName);
    final source =
        fromLanguageName != null ? _toIsoCode(fromLanguageName) : null;

    final uri = Uri.https(
      'api.cognitive.microsofttranslator.com',
      '/translate',
      <String, String>{
        'api-version': '3.0',
        'to': target,
        if (source != null) 'from': source,
      },
    );

    final resp = await http.post(
      uri,
      headers: <String, String>{
        'Ocp-Apim-Subscription-Key': key,
        'Ocp-Apim-Subscription-Region': region,
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode([
        {'Text': text},
      ]),
    );

    if (resp.statusCode != 200) {
      throw Exception(
        'Azure Translator error ${resp.statusCode}: ${resp.body}',
      );
    }
    final data = jsonDecode(resp.body) as List<dynamic>;
    if (data.isEmpty) {
      throw Exception('No translation returned');
    }
    final translations = data.first['translations'] as List<dynamic>;
    if (translations.isEmpty) {
      throw Exception('No translation returned');
    }
    return translations.first['text'] as String;
  }

  // Best-effort mapping using LanguageMappingUtility names to ISO codes.
  // Extend as needed.
  String _toIsoCode(String languageName) {
    final normalized = languageName.toLowerCase();
    switch (normalized) {
      case 'english':
        return 'en';
      case 'spanish':
        return 'es';
      case 'arabic':
      case 'egyptian arabic':
      case 'moroccan arabic':
      case 'levantine arabic':
      case 'gulf arabic':
      case 'tunisian arabic':
      case 'sudanese arabic':
      case 'iraqi arabic':
      case 'algerian arabic':
        return 'ar';
      case 'french':
        return 'fr';
      case 'german':
        return 'de';
      case 'italian':
        return 'it';
      case 'portuguese':
        return 'pt';
      case 'russian':
        return 'ru';
      case 'chinese (simplified)':
        return 'zh-CN';
      case 'chinese (traditional)':
        return 'zh-TW';
      case 'japanese':
        return 'ja';
      case 'korean':
        return 'ko';
      case 'hindi':
        return 'hi';
      case 'urdu':
        return 'ur';
      case 'turkish':
        return 'tr';
      case 'persian':
      case 'farsi':
        return 'fa';
      default:
        // Attempt to derive a code from mapping id if needed; fallback to English
        final id = LanguageMappingUtility.getLanguageId(languageName);
        log(
          'Unknown ISO mapping for "$languageName" (id: $id), defaulting to en',
        );
        return 'en';
    }
  }
}
