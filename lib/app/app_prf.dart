// ignore_for_file: constant_identifier_names

import 'package:shared_preferences/shared_preferences.dart';
import 'package:interbridge/data/services/translation_cache_service.dart';

const ONBOARDING_VIEWD_KEY = 'ONBOARDING_VIEWD_KEY';
const LOGIN_VIEWD_KEY = 'LOGIN_VIEWD_KEY';
const PENDING_REGISTRATION_KEY = 'PENDING_REGISTRATION_KEY';

class AppPreferences {
  final SharedPreferences _sharedPreferences;
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
    // Clear translation cache when user logs out
    await TranslationCacheService().clearCache();
  }

  Future<void> savePendingRegistration(String json) async {
    await _sharedPreferences.setString(PENDING_REGISTRATION_KEY, json);
  }

  String? getPendingRegistration() {
    return _sharedPreferences.getString(PENDING_REGISTRATION_KEY);
  }

  Future<void> clearPendingRegistration() async {
    await _sharedPreferences.remove(PENDING_REGISTRATION_KEY);
  }
}
