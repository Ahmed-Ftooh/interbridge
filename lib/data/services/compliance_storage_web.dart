// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ComplianceStorage {
  static const String _complianceKey = 'interpreter_compliance_timestamp';

  static Future<void> markCompliancePassed() async {
    html.window.sessionStorage[_complianceKey] = DateTime.now().millisecondsSinceEpoch.toString();
  }

  static Future<bool> hasPassedCompliance() async {
    final val = html.window.sessionStorage[_complianceKey];
    if (val == null) return false;
    
    final timestamp = int.tryParse(val);
    if (timestamp == null) return false;
    
    // Still enforces the 12-hour maximum just in case they leave the tab open all day
    final lastPassed = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(lastPassed).inHours >= 12) {
      html.window.sessionStorage.remove(_complianceKey);
      return false;
    }
    return true;
  }

  static Future<void> clearCompliance() async {
    html.window.sessionStorage.remove(_complianceKey);
  }
}