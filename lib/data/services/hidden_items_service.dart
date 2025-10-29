import 'package:shared_preferences/shared_preferences.dart';

class HiddenItemsService {
  static const String _userHiddenRequestsKey = 'user_hidden_request_ids';
  static const String _interpreterHiddenAcceptedKey =
      'interpreter_hidden_accepted_ids';
  static const String _interpreterHiddenCompletedKey =
      'interpreter_hidden_completed_ids';

  Future<Set<String>> _getIdSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? <String>[];
    return list.toSet();
  }

  Future<void> _saveIdSet(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids.toList());
  }

  // User-side hidden requests
  Future<Set<String>> getUserHiddenRequestIds() =>
      _getIdSet(_userHiddenRequestsKey);
  Future<void> hideUserRequest(String requestId) async {
    final ids = await getUserHiddenRequestIds();
    ids.add(requestId);
    await _saveIdSet(_userHiddenRequestsKey, ids);
  }

  Future<void> unhideUserRequest(String requestId) async {
    final ids = await getUserHiddenRequestIds();
    ids.remove(requestId);
    await _saveIdSet(_userHiddenRequestsKey, ids);
  }

  // Interpreter-side hidden accepted
  Future<Set<String>> getInterpreterHiddenAcceptedIds() =>
      _getIdSet(_interpreterHiddenAcceptedKey);
  Future<void> hideInterpreterAccepted(String requestId) async {
    final ids = await getInterpreterHiddenAcceptedIds();
    ids.add(requestId);
    await _saveIdSet(_interpreterHiddenAcceptedKey, ids);
  }

  // Interpreter-side hidden completed
  Future<Set<String>> getInterpreterHiddenCompletedIds() =>
      _getIdSet(_interpreterHiddenCompletedKey);
  Future<void> hideInterpreterCompleted(String requestId) async {
    final ids = await getInterpreterHiddenCompletedIds();
    ids.add(requestId);
    await _saveIdSet(_interpreterHiddenCompletedKey, ids);
  }
}
