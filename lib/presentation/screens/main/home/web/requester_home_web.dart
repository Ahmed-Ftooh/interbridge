import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/screens/main/request_waiting_view.dart';

/// Modern web-specific requester home view with dashboard layout
class RequesterHomeWeb extends StatefulWidget {
  const RequesterHomeWeb({super.key});

  @override
  State<RequesterHomeWeb> createState() => _RequesterHomeWebState();
}

class _RequesterHomeWebState extends State<RequesterHomeWeb> {
  List<Language> _allLanguages = [];
  List<Language> _interpreterLanguages = [];
  Language? _selectedFromLanguage;
  Language? _selectedToLanguage;
  bool _isLoadingLanguages = true;
  String _interpreterType = 'general';
  String? _selectedMedicalSection;
  String _callType = 'voice';

  final List<Map<String, dynamic>> _medicalSections = [
    {
      'key': 'neurology',
      'label': 'Neurology',
      'icon': FontAwesomeIcons.brain,
      'color': const Color(0xFF7C4DFF),
    },
    {
      'key': 'cardiology',
      'label': 'Cardiology',
      'icon': FontAwesomeIcons.heartPulse,
      'color': const Color(0xFFE91E63),
    },
    {
      'key': 'respiratory',
      'label': 'Respiratory',
      'icon': FontAwesomeIcons.lungs,
      'color': const Color(0xFF00BCD4),
    },
    {
      'key': 'gastrointestinal',
      'label': 'Gastrointestinal',
      'icon': FontAwesomeIcons.disease,
      'color': const Color(0xFFFF9800),
    },
    {
      'key': 'endocrinology',
      'label': 'Endocrinology',
      'icon': FontAwesomeIcons.vial,
      'color': const Color(0xFF9C27B0),
    },
    {
      'key': 'renal',
      'label': 'Renal',
      'icon': FontAwesomeIcons.droplet,
      'color': const Color(0xFF2196F3),
    },
    {
      'key': 'ob_gyn',
      'label': 'OB/GYN',
      'icon': FontAwesomeIcons.personBreastfeeding,
      'color': const Color(0xFFE91E63),
    },
    {
      'key': 'oncology',
      'label': 'Oncology',
      'icon': FontAwesomeIcons.ribbon,
      'color': const Color(0xFF607D8B),
    },
    {
      'key': 'emergency',
      'label': 'Emergency',
      'icon': FontAwesomeIcons.truckMedical,
      'color': const Color(0xFFF44336),
    },
    {
      'key': 'psychology',
      'label': 'Psychology',
      'icon': FontAwesomeIcons.commentMedical,
      'color': const Color(0xFF4CAF50),
    },
    {
      'key': 'musculoskeletal',
      'label': 'Musculoskeletal',
      'icon': FontAwesomeIcons.bone,
      'color': const Color(0xFF795548),
    },
    {
      'key': 'dermatology',
      'label': 'Dermatology',
      'icon': FontAwesomeIcons.handDots,
      'color': const Color(0xFFFFB74D),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    try {
      final supabaseService = SupabaseService();
      final results = await Future.wait([
        supabaseService.getLanguages(),
        supabaseService.getAvailableInterpreterLanguages(),
      ]);

      if (mounted) {
        final allLangs = results[0];
        final interpreterLangs = results[1];
        allLangs.sort((a, b) => a.name.compareTo(b.name));
        interpreterLangs.sort((a, b) => a.name.compareTo(b.name));

        final english = allLangs.firstWhere(
          (l) => l.name.toLowerCase() == 'english',
          orElse:
              () =>
                  allLangs.isNotEmpty
                      ? allLangs.first
                      : Language(id: 0, name: 'English'),
        );

        setState(() {
          _allLanguages = allLangs;
          _interpreterLanguages = interpreterLangs;
          _selectedFromLanguage = english;
          _isLoadingLanguages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLanguages = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1400;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          _buildWelcomeHeader(),
          const SizedBox(height: 32),

          // Main content
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Request form
                Expanded(flex: 3, child: _buildRequestCard()),
                const SizedBox(width: 24),
                // Right side - Stats and quick actions
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildStatsCard(),
                      const SizedBox(height: 24),
                      _buildQuickActionsCard(),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildRequestCard(),
                const SizedBox(height: 24),
                _buildStatsCard(),
                const SizedBox(height: 24),
                _buildQuickActionsCard(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0955FA).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back! 👋',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Request a medical interpreter instantly. Choose your languages and connect with a qualified interpreter.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              size: 64,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.translate,
                  color: Color(0xFF0955FA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Interpreter',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Select your preferences below',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Language selection row
          _buildSectionTitle('Languages', Icons.language),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildLanguageDropdown(
                  'You speak',
                  _selectedFromLanguage,
                  _allLanguages,
                  (lang) {
                    setState(() => _selectedFromLanguage = lang);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_horiz, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLanguageDropdown(
                  'Patient speaks',
                  _selectedToLanguage,
                  _interpreterLanguages,
                  (lang) {
                    setState(() => _selectedToLanguage = lang);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Interpreter type
          _buildSectionTitle('Interpreter Type', Icons.person_search),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTypeCard(
                  'general',
                  'General',
                  'Basic medical interpretation',
                  Icons.person,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTypeCard(
                  'specialist',
                  'Specialist',
                  'Specialized medical fields',
                  Icons.medical_information,
                ),
              ),
            ],
          ),

          // Medical sections (if specialist)
          if (_interpreterType == 'specialist') ...[
            const SizedBox(height: 32),
            _buildSectionTitle('Medical Specialty', Icons.local_hospital),
            const SizedBox(height: 16),
            _buildMedicalSectionsGrid(),
          ],
          const SizedBox(height: 32),

          // Call type
          _buildSectionTitle('Call Type', Icons.call),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCallTypeCard('voice', 'Voice Call', Icons.phone),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCallTypeCard(
                  'video',
                  'Video Call',
                  Icons.videocam,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Request button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit() ? _submitRequest : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0955FA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _callType == 'video' ? Icons.videocam : Icons.phone,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Request ${_callType == 'video' ? 'Video' : 'Voice'} Interpreter',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown(
    String label,
    Language? selected,
    List<Language> options,
    Function(Language?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Language>(
              value: selected,
              hint: const Text('Select language'),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items:
                  options.map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text(lang.name),
                    );
                  }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard(
    String type,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _interpreterType == type;
    return InkWell(
      onTap: () => setState(() => _interpreterType = type),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF0955FA).withValues(alpha: 0.08)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0955FA) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? const Color(0xFF0955FA).withValues(alpha: 0.1)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color:
                    isSelected
                        ? const Color(0xFF0955FA)
                        : const Color(0xFF64748B),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected
                              ? const Color(0xFF0955FA)
                              : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF0955FA),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalSectionsGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          _medicalSections.map((section) {
            final isSelected = _selectedMedicalSection == section['key'];
            return InkWell(
              onTap:
                  () =>
                      setState(() => _selectedMedicalSection = section['key']),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? (section['color'] as Color).withValues(alpha: 0.1)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected
                            ? section['color'] as Color
                            : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      section['icon'] as IconData,
                      size: 16,
                      color:
                          isSelected
                              ? section['color'] as Color
                              : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      section['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color:
                            isSelected
                                ? section['color'] as Color
                                : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildCallTypeCard(String type, String label, IconData icon) {
    final isSelected = _callType == type;
    return InkWell(
      onTap: () => setState(() => _callType = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF0955FA).withValues(alpha: 0.08)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0955FA) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? const Color(0xFF0955FA)
                      : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color:
                    isSelected
                        ? const Color(0xFF0955FA)
                        : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          _buildStatRow(
            'Total Calls',
            '24',
            Icons.phone_in_talk,
            const Color(0xFF0955FA),
          ),
          const Divider(height: 24),
          _buildStatRow(
            'This Month',
            '8',
            Icons.calendar_today,
            const Color(0xFF22C55E),
          ),
          const Divider(height: 24),
          _buildStatRow(
            'Avg. Duration',
            '12 min',
            Icons.timer,
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton(
            'Document Translation',
            Icons.description_outlined,
            const Color(0xFF6366F1),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'View History',
            Icons.history,
            const Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            'Get Help',
            Icons.help_outline,
            const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSubmit() {
    if (_selectedFromLanguage == null || _selectedToLanguage == null)
      return false;
    if (_interpreterType == 'specialist' && _selectedMedicalSection == null)
      return false;
    return true;
  }

  void _submitRequest() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => RequestWaitingView(
              fromLanguageId: _selectedFromLanguage!.name,
              toLanguageId: _selectedToLanguage!.name,
              specialization:
                  _interpreterType == 'specialist'
                      ? _selectedMedicalSection
                      : null,
              urgency: 'normal',
              interpreterType: _interpreterType,
              medicalSection: _selectedMedicalSection,
              callType: _callType,
            ),
      ),
    );
  }
}
