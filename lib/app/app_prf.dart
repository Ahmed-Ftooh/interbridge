// ignore_for_file: constant_identifier_names

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:interbridge/data/services/translation_cache_service.dart';

const ONBOARDING_VIEWD_KEY = 'ONBOARDING_VIEWD_KEY';
const LOGIN_VIEWD_KEY = 'LOGIN_VIEWD_KEY';
const PENDING_REGISTRATION_KEY = 'PENDING_REGISTRATION_KEY';
const QUIZ_ONBOARDING_DONE_KEY = 'QUIZ_ONBOARDING_DONE_KEY';

class AppPreferences {
  final SharedPreferences _sharedPreferences;
  // Big Company Best Practice: Use Secure Storage for PII / Auth objects
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  AppPreferences(this._sharedPreferences);

  Future<void> setOnbordingViewed() async {
    await _sharedPreferences.setBool(ONBOARDING_VIEWD_KEY, true);
  }

  Future<bool> isOnboardingViewed() async {
    return _sharedPreferences.getBool(ONBOARDING_VIEWD_KEY) ?? false;
  }

  Future<void> setLoginViewed() async {
    await _sharedPreferences.setBool(LOGIN_VIEWD_KEY, true);
  }

  Future<bool> isLoginViewed() async {
    return _sharedPreferences.getBool(LOGIN_VIEWD_KEY) ?? false;
  }

  Future<void> logout() async {
    _sharedPreferences.remove(LOGIN_VIEWD_KEY);
    _sharedPreferences.remove(QUIZ_ONBOARDING_DONE_KEY);
    await _secureStorage.delete(key: PENDING_REGISTRATION_KEY);
    // Clear translation cache when user logs out
    await TranslationCacheService().clearCache();
  }

  Future<void> savePendingRegistration(String json) async {
    // Keep legacy path for backwards compatibility initially, but write to secure 
    await _sharedPreferences.setString(PENDING_REGISTRATION_KEY, json);
    await _secureStorage.write(key: PENDING_REGISTRATION_KEY, value: json);
  }

  // NOTE: This remains synchronous because it serves a lot of build() functions,
  // but it now prefers checking SharedPreferences to avoid refactoring the entire
  // app's sync logic. Realistically in an enterprise app, this should be purely 
  // async and backed solely by SecureStorage.
  String? getPendingRegistration() {
    return _sharedPreferences.getString(PENDING_REGISTRATION_KEY);
  }

  Future<void> clearPendingRegistration() async {
    await _sharedPreferences.remove(PENDING_REGISTRATION_KEY);
    await _secureStorage.delete(key: PENDING_REGISTRATION_KEY);
  }

  Future<void> setQuizOnboardingDone() async {
    await _sharedPreferences.setBool(QUIZ_ONBOARDING_DONE_KEY, true);
  }

  bool isQuizOnboardingDone() {
    return _sharedPreferences.getBool(QUIZ_ONBOARDING_DONE_KEY) ?? false;
  }
}
