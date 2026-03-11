import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/data/services/auto_routing_service.dart';
import 'package:interbridge/presentation/screens/main/request_waiting_view.dart';

/// Modern web-specific requester home view with dashboard layout.
/// Pre-call intake is 4 fields (~10 seconds) then auto-connect.
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
  final String _interpreterType = 'general';
  String? _selectedMedicalSection;
  String _callType = 'voice';

  // Pre-call intake fields
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();
  String? _selectedDepartment;
  int _availableInterpreters = 0;
  bool _isCheckingAvailability = false;

  static const List<Map<String, dynamic>> _departments = [
    {
      'key': 'emergency',
      'label': 'Emergency',
      'icon': FontAwesomeIcons.truckMedical,
    },
    {'key': 'icu', 'label': 'ICU', 'icon': FontAwesomeIcons.bedPulse},
    {'key': 'surgery', 'label': 'Surgery', 'icon': FontAwesomeIcons.syringe},
    {'key': 'pediatrics', 'label': 'Pediatrics', 'icon': FontAwesomeIcons.baby},
    {'key': 'oncology', 'label': 'Oncology', 'icon': FontAwesomeIcons.ribbon},
    {
      'key': 'cardiology',
      'label': 'Cardiology',
      'icon': FontAwesomeIcons.heartPulse,
    },
    {'key': 'neurology', 'label': 'Neurology', 'icon': FontAwesomeIcons.brain},
    {'key': 'radiology', 'label': 'Radiology', 'icon': FontAwesomeIcons.xRay},
    {
      'key': 'ob_gyn',
      'label': 'OB/GYN',
      'icon': FontAwesomeIcons.personBreastfeeding,
    },
    {
      'key': 'orthopedics',
      'label': 'Orthopedics',
      'icon': FontAwesomeIcons.bone,
    },
    {
      'key': 'psychiatry',
      'label': 'Psychiatry',
      'icon': FontAwesomeIcons.commentMedical,
    },
    {
      'key': 'general',
      'label': 'General / Other',
      'icon': FontAwesomeIcons.hospitalUser,
    },
  ];

  // Department list is defined in _departments static const

  @override
  void initState() {
    super.initState();
    _loadLanguages();
    _tryAutoFillDoctor();
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _patientIdController.dispose();
    super.dispose();
  }

  /// Try to auto-fill doctor name from profile
  Future<void> _tryAutoFillDoctor() async {
    try {
      final user = SupabaseService().client.auth.currentUser;
      if (user != null) {
        final profile =
            await SupabaseService().client
                .from('profiles')
                .select('full_name')
                .eq('user_id', user.id)
                .maybeSingle();
        if (profile != null && profile['full_name'] != null && mounted) {
          _doctorNameController.text = profile['full_name'] as String;
        }
      }
    } catch (_) {}
  }

  /// Check available interpreter count when language changes
  Future<void> _checkAvailability() async {
    if (_selectedFromLanguage == null || _selectedToLanguage == null) return;
    setState(() => _isCheckingAvailability = true);
    try {
      final count = await AutoRoutingService().getAvailableCount(
        fromLanguage: _selectedFromLanguage!.name,
        toLanguage: _selectedToLanguage!.name,
      );
      if (mounted) {
        setState(() {
          _availableInterpreters = count;
          _isCheckingAvailability = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingAvailability = false);
    }
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0955FA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFF0955FA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Connect',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Fill in details below — we\'ll find the best interpreter automatically',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              // Availability indicator
              if (_selectedToLanguage != null) ...[
                const SizedBox(width: 16),
                _buildAvailabilityBadge(),
              ],
            ],
          ),
          const SizedBox(height: 28),

          // ── Step 1: Language pair (essential) ──
          _buildSectionTitle('Language', Icons.language),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLanguageDropdown(
                  'You speak',
                  _selectedFromLanguage,
                  _allLanguages,
                  (lang) {
                    setState(() => _selectedFromLanguage = lang);
                    _checkAvailability();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLanguageDropdown(
                  'Patient speaks',
                  _selectedToLanguage,
                  _interpreterLanguages,
                  (lang) {
                    setState(() => _selectedToLanguage = lang);
                    _checkAvailability();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Step 2: Intake fields (2-column layout) ──
          _buildSectionTitle('Session Details', Icons.assignment_outlined),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _doctorNameController,
                  label: 'Your Name',
                  hint: 'Dr. Smith',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _patientIdController,
                  label: 'Patient ID / MRN',
                  hint: 'e.g. PT-00421',
                  icon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDepartmentDropdown(),
          const SizedBox(height: 24),

          // ── Step 3: Call type (compact) ──
          Row(
            children: [
              Expanded(
                child: _buildCallTypeChip('voice', 'Voice Call', Icons.phone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCallTypeChip(
                  'video',
                  'Video Call',
                  Icons.videocam,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Connect button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit() ? _submitAutoRoute : null,
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
                  const Icon(Icons.flash_on_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Connect Now${_callType == 'video' ? ' (Video)' : ''}',
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

  Widget _buildAvailabilityBadge() {
    if (_isCheckingAvailability) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final color =
        _availableInterpreters > 0
            ? const Color(0xFF22C55E)
            : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            _availableInterpreters > 0
                ? '$_availableInterpreters available'
                : 'Queue expected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
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
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0955FA), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Department',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDepartment,
              hint: const Text('Select department'),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items:
                  _departments.map((dept) {
                    return DropdownMenuItem<String>(
                      value: dept['key'] as String,
                      child: Row(
                        children: [
                          FaIcon(
                            dept['icon'] as IconData,
                            size: 16,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Text(dept['label'] as String),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (val) => setState(() => _selectedDepartment = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallTypeChip(String type, String label, IconData icon) {
    final isSelected = _callType == type;
    return InkWell(
      onTap: () => setState(() => _callType = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
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
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
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

  // _buildTypeCard and _buildMedicalSectionsGrid removed — auto-routing
  // picks the best interpreter type automatically based on department/language.

  // _buildCallTypeCard removed — replaced with _buildCallTypeChip above

  bool _canSubmit() {
    if (_selectedFromLanguage == null || _selectedToLanguage == null) {
      return false;
    }
    return true;
  }

  void _submitAutoRoute() {
    // Navigate to RequestWaitingView with auto-route mode
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => RequestWaitingView(
              fromLanguageId: _selectedFromLanguage!.name,
              toLanguageId: _selectedToLanguage!.name,
              specialization: _selectedDepartment,
              urgency: 'normal',
              interpreterType: _interpreterType,
              medicalSection: _selectedMedicalSection ?? _selectedDepartment,
              callType: _callType,
              // New auto-routing fields
              useAutoRouting: true,
              doctorName:
                  _doctorNameController.text.trim().isNotEmpty
                      ? _doctorNameController.text.trim()
                      : null,
              patientId:
                  _patientIdController.text.trim().isNotEmpty
                      ? _patientIdController.text.trim()
                      : null,
              department: _selectedDepartment,
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
}
