import 'package:supabase_flutter/supabase_flutter.dart';

/// Mobile stub. This is never actually used because we check `kIsWeb` in app_initializer
class WebSessionStorage extends LocalStorage {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => false;
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<void> persistSession(String persistSessionString) async {}
  @override
  Future<void> removePersistedSession() async {}
}