import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation using sessionStorage
class WebSessionStorage extends LocalStorage {
  final String _storageKey = 'supabase_auth_token';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return html.window.sessionStorage.containsKey(_storageKey);
  }

  @override
  Future<String?> accessToken() async {
    return html.window.sessionStorage[_storageKey];
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    html.window.sessionStorage[_storageKey] = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    html.window.sessionStorage.remove(_storageKey);
  }
}