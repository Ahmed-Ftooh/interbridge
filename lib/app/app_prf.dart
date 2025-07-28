// ignore_for_file: constant_identifier_names

import 'package:shared_preferences/shared_preferences.dart';

const ONBOARDING_VIEWD_KEY = 'ONBOARDING_VIEWD_KEY';
const LOGIN_VIEWD_KEY = 'LOGIN_VIEWD_KEY';

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
}
