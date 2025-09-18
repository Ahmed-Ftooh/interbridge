import 'package:flutter/material.dart';
import 'package:interbridge/data/services/agora_debug_service.dart';
import 'package:interbridge/data/services/call_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

class AgoraDebugWidget extends StatefulWidget {
  const AgoraDebugWidget({super.key});

  @override
  State<AgoraDebugWidget> createState() => _AgoraDebugWidgetState();
}

class _AgoraDebugWidgetState extends State<AgoraDebugWidget> {
  bool _isRunningTests = false;
  Map<String, bool> _testResults = {};
  String _logOutput = '';

  void _addLog(String message) {
    setState(() {
      _logOutput +=
          '${DateTime.now().toString().substring(11, 19)}: $message\n';
    });
  }

  Future<void> _runDiagnosticTests() async {
    setState(() {
      _isRunningTests = true;
      _logOutput = '';
      _testResults = {};
    });

    try {
      _addLog('🚀 Starting Agora diagnostic tests...');

      final results = await AgoraDebugService.runAllTests();

      setState(() {
        _testResults = results;
      });

      _addLog('📊 Tests completed!');
      results.forEach((test, result) {
        _addLog('${result ? '✅' : '❌'} $test');
      });

      final allPassed = results.values.every((result) => result);
      _addLog(allPassed ? '🎉 All tests passed!' : '⚠️ Some tests failed');
    } catch (e) {
      _addLog('❌ Error running tests: $e');
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }

  Future<void> _testTokenGeneration() async {
    try {
      _addLog('🔑 Testing token generation...');

      final callService = CallService();
      final token = await callService.fetchAgoraToken(
        channelName: 'test-channel-${DateTime.now().millisecondsSinceEpoch}',
        uid: 123,
      );

      _addLog('✅ Token generated successfully!');
      _addLog('Token length: ${token.length} characters');
      _addLog('Token preview: ${token.substring(0, 20)}...');
    } catch (e) {
      _addLog('❌ Token generation failed: $e');
    }
  }

  Future<void> _cleanup() async {
    try {
      _addLog('🧹 Cleaning up Agora engine...');
      await AgoraDebugService.cleanup();
      _addLog('✅ Cleanup completed');
    } catch (e) {
      _addLog('❌ Cleanup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(AppSize.s16),
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: ColorManager.primary2,
                  size: AppSize.s24,
                ),
                const SizedBox(width: AppSize.s8),
                Text(
                  'Agora Debug Panel',
                  style: TextStyle(
                    fontSize: AppSize.s18,
                    fontWeight: FontWeight.bold,
                    color: ColorManager.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSize.s16),

            // Test Results
            if (_testResults.isNotEmpty) ...[
              Text(
                'Test Results:',
                style: TextStyle(
                  fontSize: AppSize.s16,
                  fontWeight: FontWeight.w600,
                  color: ColorManager.textPrimary,
                ),
              ),
              const SizedBox(height: AppSize.s8),
              ..._testResults.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSize.s4),
                  child: Row(
                    children: [
                      Icon(
                        entry.value ? Icons.check_circle : Icons.error,
                        color: entry.value ? Colors.green : Colors.red,
                        size: AppSize.s16,
                      ),
                      const SizedBox(width: AppSize.s8),
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: entry.value ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSize.s16),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunningTests ? null : _runDiagnosticTests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.primary2,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        _isRunningTests
                            ? const SizedBox(
                              height: AppSize.s20,
                              width: AppSize.s20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text('Run Diagnostic Tests'),
                  ),
                ),
                const SizedBox(width: AppSize.s8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testTokenGeneration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorManager.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test Token'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSize.s8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cleanup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.greyMedium,
                  foregroundColor: ColorManager.textPrimary,
                ),
                child: const Text('Cleanup Engine'),
              ),
            ),

            const SizedBox(height: AppSize.s16),

            // Log Output
            Text(
              'Debug Log:',
              style: TextStyle(
                fontSize: AppSize.s14,
                fontWeight: FontWeight.w600,
                color: ColorManager.textPrimary,
              ),
            ),
            const SizedBox(height: AppSize.s8),

            Container(
              width: double.infinity,
              height: 200,
              padding: const EdgeInsets.all(AppSize.s8),
              decoration: BoxDecoration(
                color: ColorManager.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppSize.s8),
                border: Border.all(color: ColorManager.greyMedium),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _logOutput.isEmpty
                      ? 'No logs yet. Run tests to see output.'
                      : _logOutput,
                  style: TextStyle(
                    fontSize: AppSize.s12,
                    fontFamily: 'monospace',
                    color: ColorManager.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

