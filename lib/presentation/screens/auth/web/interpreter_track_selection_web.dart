import 'package:flutter/material.dart';
import 'package:interbridge/data/models/interpreter_level.dart';
import 'package:interbridge/data/models/interpreter_track.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart';

/// Professional web interpreter track selection screen
class InterpreterTrackSelectionWebScreen extends StatefulWidget {
  const InterpreterTrackSelectionWebScreen({super.key});

  @override
  State<InterpreterTrackSelectionWebScreen> createState() =>
      _InterpreterTrackSelectionWebScreenState();
}

class _InterpreterTrackSelectionWebScreenState
    extends State<InterpreterTrackSelectionWebScreen> {
  InterpreterLevel? _selectedLevel;
  String? _hoveredTrack;

  @override
  Widget build(BuildContext context) {
    return AuthWebWrapper(
      title: 'Choose your track',
      subtitle: 'Select the path that matches your experience level',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step indicator
          _buildStepIndicator(1, 9),
          const SizedBox(height: 32),

          _buildTrackCard(
            trackId: 'volunteer',
            icon: Icons.school_rounded,
            title: 'Entry-Level Beginner',
            subtitle: 'Start with basic medical calls',
            features: const [
              'Build your experience',
              'Support humanitarian causes',
              'Earn recognition & certificates',
            ],
            isSelected: _selectedLevel == InterpreterLevel.volunteer,
            onTap:
                () =>
                    setState(() => _selectedLevel = InterpreterLevel.volunteer),
          ),
          const SizedBox(height: 16),

          _buildTrackCard(
            trackId: 'paid',
            icon: Icons.workspace_premium_rounded,
            title: 'Experienced Professional',
            subtitle: 'Medical & specialized interpretation',
            features: const [
              'Complete medical section quizzes',
              'Qualify for paid shifts',
              'Access specialized assignments',
            ],
            isSelected: _selectedLevel == InterpreterLevel.paid,
            onTap: () => setState(() => _selectedLevel = InterpreterLevel.paid),
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedLevel != null ? _continue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF94A3B8),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
              child: const Text('Back to sign in'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i < current;
        final isCurrent = i == current - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color:
                  isCurrent
                      ? const Color(0xFF3B82F6)
                      : isActive
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTrackCard({
    required String trackId,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> features,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isHovered = _hoveredTrack == trackId;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTrack = trackId),
      onExit: (_) => setState(() => _hoveredTrack = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFFF0F7FF)
                  : isHovered
                  ? const Color(0xFFFAFAFA)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF3B82F6)
                    : isHovered
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Radio
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                      color:
                          isSelected
                              ? const Color(0xFF3B82F6)
                              : Colors.transparent,
                    ),
                    child:
                        isSelected
                            ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                            : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color:
                                  isSelected
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? const Color(0xFF1E40AF)
                                        : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...features.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color:
                                      isSelected
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        isSelected
                                            ? const Color(0xFF334155)
                                            : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _continue() {
    if (_selectedLevel == null) return;

    final track =
        _selectedLevel == InterpreterLevel.volunteer
            ? InterpreterTrack.volunteer
            : InterpreterTrack.paid;

    final args = <String, dynamic>{
      'role': 'interpreter',
      'interpreterLevel': _selectedLevel!.name,
      'interpreterTrack': track.name,
      'requiresMedicalDocs': _selectedLevel == InterpreterLevel.paid,
    };
    Navigator.of(context).pushNamed(Routes.selectLanguage, arguments: args);
  }
}
