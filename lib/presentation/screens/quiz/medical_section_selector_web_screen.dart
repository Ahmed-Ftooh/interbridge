import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/screens/quiz/quiz_web_screen.dart';

/// Web version of the medical section selector grid.
/// Shows 10 medical specializations with earned badge indicators.
class MedicalSectionSelectorWebScreen extends StatefulWidget {
  final Future<void> Function(String sectionId)? onSectionTap;

  const MedicalSectionSelectorWebScreen({super.key, this.onSectionTap});

  @override
  State<MedicalSectionSelectorWebScreen> createState() =>
      _MedicalSectionSelectorWebScreenState();
}

class _MedicalSectionSelectorWebScreenState
    extends State<MedicalSectionSelectorWebScreen> {
  final _supabase = SupabaseService();
  final List<_MedicalSection> _sections = const [
    _MedicalSection('neurology', 'Neurology', FontAwesomeIcons.brain),
    _MedicalSection('cardiology', 'Cardiology', FontAwesomeIcons.heartPulse),
    _MedicalSection('respiratory', 'Respiratory', FontAwesomeIcons.lungs),
    _MedicalSection(
      'gastrointestinal',
      'Gastrointestinal',
      FontAwesomeIcons.disease,
    ),
    _MedicalSection('endocrinology', 'Endocrinology', FontAwesomeIcons.vial),
    _MedicalSection('renal', 'Renal System', FontAwesomeIcons.droplet),
    _MedicalSection('ob_gyn', 'OB/GYN', FontAwesomeIcons.personBreastfeeding),
    _MedicalSection('oncology', 'Oncology', FontAwesomeIcons.ribbon),
    _MedicalSection('emergency', 'Emergency', FontAwesomeIcons.truckMedical),
    _MedicalSection('dermatology', 'Dermatology', FontAwesomeIcons.handDots),
  ];

  Map<String, bool> _earnedBadges = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserBadges();
  }

  Future<void> _loadUserBadges() async {
    try {
      final user = _supabase.getCurrentUser();
      if (user != null) {
        final badges = await _supabase.getUserBadges(user.id);
        setState(() {
          _earnedBadges = {for (var b in badges) b['badge'] as String: true};
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Failed to load badges: $e');
    }
  }

  Future<void> _startSection(String sectionId) async {
    if (widget.onSectionTap != null) {
      await widget.onSectionTap!(sectionId);
      await _loadUserBadges();
      return;
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder:
            (_) =>
                QuizWebScreen(quizType: 'medical', medicalSection: sectionId),
      ),
    );

    if (result != null && result['passed'] == true) {
      await _loadUserBadges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Medical Specializations',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Earn Badges',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete each section quiz to earn a badge',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 28),

                // Grid
                Expanded(
                  child:
                      _loading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF0F172A),
                            ),
                          )
                          : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.1,
                                ),
                            itemCount: _sections.length,
                            itemBuilder: (context, index) {
                              final section = _sections[index];
                              final earned = _earnedBadges[section.id] == true;
                              return _SectionCard(
                                section: section,
                                earned: earned,
                                onTap: () => _startSection(section.id),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicalSection {
  final String id;
  final String name;
  final IconData icon;

  const _MedicalSection(this.id, this.name, this.icon);
}

class _SectionCard extends StatefulWidget {
  final _MedicalSection section;
  final bool earned;
  final VoidCallback onTap;

  const _SectionCard({
    required this.section,
    required this.earned,
    required this.onTap,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  widget.earned
                      ? const Color(0xFF10B981)
                      : _isHovered
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0),
              width: widget.earned ? 2 : 1,
            ),
            boxShadow:
                _isHovered
                    ? [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          widget.earned
                              ? const Color(0xFF10B981).withValues(alpha: 0.08)
                              : const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      widget.section.icon,
                      size: 28,
                      color:
                          widget.earned
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                    ),
                  ),
                  if (widget.earned)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.section.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.earned) ...[
                const SizedBox(height: 4),
                const Text(
                  'Earned',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
