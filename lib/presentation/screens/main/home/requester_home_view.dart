import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/screens/main/request_waiting_view.dart';

class RequesterHomeView extends StatefulWidget {
  const RequesterHomeView({super.key});

  @override
  State<RequesterHomeView> createState() => _RequesterHomeViewState();
}

class _RequesterHomeViewState extends State<RequesterHomeView>
    with SingleTickerProviderStateMixin {
  // All languages for "from" selection (client speaks)
  List<Language> _allLanguages = [];
  // Languages available for "to" selection based on selected "from"
  List<Language> _availableToLanguages = [];
  final Map<int, List<Language>> _toLanguageCache = {};
  Language? _selectedFromLanguage;
  Language? _selectedToLanguage;
  bool _isLoadingLanguages = true;
  bool _isLoadingToLanguages = false;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Interpreter type: 'general' or 'specialist'
  String _interpreterType = 'general';

  // Selected medical section
  String? _selectedMedicalSection;

  // Call type: 'voice' or 'video'
  String _callType = 'voice';

  // Medical sections with icons and colors
  // Using Font Awesome icons for accurate medical representations
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
    {
      'key': 'ear & eye',
      'label': 'Ear & Eye',
      'icon': FontAwesomeIcons.eye,
      'color': Colors.indigo,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadLanguages();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguages() async {
    try {
      final supabaseService = SupabaseService();
      // Load all languages for "from" (client speaks)
      final allLangs = await supabaseService.getLanguages();

      if (mounted) {
        // Sort alphabetically
        allLangs.sort((a, b) => a.name.compareTo(b.name));

        setState(() {
          _allLanguages = allLangs;
          _isLoadingLanguages = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLanguages = false;
        });
        _animationController.forward();
      }
    }
  }

  Language? _selectValidToLanguage(
    Language? previous,
    List<Language> options,
  ) {
    if (previous != null) {
      for (final option in options) {
        if (option.id == previous.id) {
          return option;
        }
      }
    }

    if (options.length == 1) {
      return options.first;
    }

    return null;
  }

  Future<void> _loadToLanguagesForFrom(
    int fromLanguageId, {
    Language? previousSelection,
  }) async {
    final cached = _toLanguageCache[fromLanguageId];
    if (cached != null) {
      if (!mounted || _selectedFromLanguage?.id != fromLanguageId) return;
      setState(() {
        _availableToLanguages = cached;
        _isLoadingToLanguages = false;
        _selectedToLanguage = _selectValidToLanguage(previousSelection, cached);
      });
      return;
    }

    try {
      final supabaseService = SupabaseService();
      final toLanguages =
          await supabaseService.getAvailableToLanguagesForFromLanguage(
            fromLanguageId,
          );

      toLanguages.sort((a, b) => a.name.compareTo(b.name));

      if (!mounted || _selectedFromLanguage?.id != fromLanguageId) return;

      setState(() {
        _availableToLanguages = toLanguages;
        _toLanguageCache[fromLanguageId] = toLanguages;
        _isLoadingToLanguages = false;
        _selectedToLanguage = _selectValidToLanguage(
          previousSelection,
          toLanguages,
        );
      });
    } catch (e) {
      if (!mounted || _selectedFromLanguage?.id != fromLanguageId) return;
      setState(() {
        _availableToLanguages = [];
        _isLoadingToLanguages = false;
        _selectedToLanguage = null;
      });
    }
  }

  void _handleFromLanguageSelected(Language language) {
    if (_selectedFromLanguage?.id == language.id) return;

    final previousTo = _selectedToLanguage;

    setState(() {
      _selectedFromLanguage = language;
      _selectedToLanguage = null;
      _availableToLanguages = [];
      _isLoadingToLanguages = true;
    });

    _loadToLanguagesForFrom(
      language.id,
      previousSelection: previousTo,
    );
  }

  String _toLanguagePlaceholder() {
    if (_selectedFromLanguage == null) {
      return 'Select client language first';
    }
    if (_isLoadingToLanguages) {
      return 'Loading available languages...';
    }
    if (_availableToLanguages.isEmpty) {
      return 'No interpreters available';
    }
    return 'Select language';
  }

  bool get _canStartRequest {
    if (_selectedFromLanguage == null || _selectedToLanguage == null) {
      return false;
    }
    if (_interpreterType == 'specialist' && _selectedMedicalSection == null) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body:
          _isLoadingLanguages
              ? _buildLoadingState()
              : FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  slivers: [
                    // Custom App Bar
                    _buildSliverAppBar(),

                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 24),

                          // Language Selection Card
                          _buildLanguageCard(),

                          const SizedBox(height: 20),

                          // Interpreter Type
                          _buildInterpreterTypeSection(),

                          // Medical Sections (animated)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child:
                                _interpreterType == 'specialist'
                                    ? _buildMedicalSectionsCard()
                                    : const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 20),

                          // Call Type
                          _buildCallTypeSection(),

                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      // Floating Action Button
      floatingActionButton:
          _isLoadingLanguages
              ? null
              : AnimatedScale(
                scale: _canStartRequest ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: _buildFloatingButton(),
              ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(ColorManager.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading languages...',
            style: TextStyle(
              color: ColorManager.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: ColorManager.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorManager.primary,
                ColorManager.primary.withOpacity(0.8),
                ColorManager.primary2,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome Doctor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect instantly with professionals',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ColorManager.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.translate_rounded,
                  color: ColorManager.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Translation Languages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // From Language (Client Speaks) - All languages
          _buildLanguageSelector(
            label: 'Client Speaks',
            language: _selectedFromLanguage,
            languages: _allLanguages,
            icon: Icons.record_voice_over_rounded,
            color: const Color(0xFF3B82F6),
            onSelect: _handleFromLanguageSelected,
          ),

          // Arrow indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  color: ColorManager.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),

          // To Language (Patient Speaks) - Only interpreter languages
          _buildLanguageSelector(
            label: 'Patient speaks',
            language: _selectedToLanguage,
            languages: _availableToLanguages,
            icon: Icons.person_rounded,
            color: const Color(0xFF10B981),
            placeholder: _toLanguagePlaceholder(),
            enabled: _selectedFromLanguage != null,
            isLoading: _isLoadingToLanguages,
            onSelect: (lang) => setState(() => _selectedToLanguage = lang),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector({
    required String label,
    required Language? language,
    required List<Language> languages,
    required IconData icon,
    required Color color,
    required ValueChanged<Language> onSelect,
    String? placeholder,
    bool enabled = true,
    bool isLoading = false,
  }) {
    final isEnabled = enabled && !isLoading && languages.isNotEmpty;
    final displayText = language?.name ?? (placeholder ?? 'Select language');
    final displayColor =
        language != null
            ? const Color(0xFF1E293B)
            : isEnabled
            ? ColorManager.textSecondary
            : const Color(0xFF94A3B8);

    return InkWell(
      onTap:
          isEnabled
              ? () => _showLanguageBottomSheet(languages, language, onSelect)
              : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                language != null
                    ? color.withOpacity(0.3)
                    : const Color(0xFFE2E8F0),
            width: language != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorManager.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: displayColor,
                    ),
                  ),
                ],
              ),
            ),
            isLoading
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      ColorManager.textSecondary,
                    ),
                  ),
                )
                : Icon(
                  Icons.chevron_right_rounded,
                  color: ColorManager.textSecondary,
                  size: 24,
                ),
          ],
        ),
      ),
    );
  }

  void _showLanguageBottomSheet(
    List<Language> languages,
    Language? selected,
    ValueChanged<Language> onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';
        List<Language> filtered = languages;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyFilter(String value) {
              setModalState(() {
                searchQuery = value.trim();
                filtered =
                    languages
                        .where(
                          (lang) => lang.name.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Row(
                          children: [
                            const Text(
                              'Select Language',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Search
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          onChanged: applyFilter,
                          decoration: InputDecoration(
                            hintText: 'Search languages...',
                            hintStyle: TextStyle(
                              color: ColorManager.textSecondary,
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: ColorManager.textSecondary,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // List
                      Expanded(
                        child:
                            filtered.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 48,
                                        color: ColorManager.textSecondary,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No languages found',
                                        style: TextStyle(
                                          color: ColorManager.textSecondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final lang = filtered[index];
                                    final isSelected = selected?.id == lang.id;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Material(
                                        color:
                                            isSelected
                                                ? ColorManager.primary
                                                    .withOpacity(0.1)
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          onTap: () {
                                            onSelect(lang);
                                            Navigator.pop(context);
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isSelected
                                                            ? ColorManager
                                                                .primary
                                                            : const Color(
                                                              0xFFF1F5F9,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      lang.name
                                                          .substring(0, 2)
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            isSelected
                                                                ? Colors.white
                                                                : const Color(
                                                                  0xFF64748B,
                                                                ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Text(
                                                    lang.name,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          isSelected
                                                              ? FontWeight.w600
                                                              : FontWeight.w500,
                                                      color:
                                                          isSelected
                                                              ? ColorManager
                                                                  .primary
                                                              : const Color(
                                                                0xFF1E293B,
                                                              ),
                                                    ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: ColorManager.primary,
                                                    size: 22,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInterpreterTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Interpreter Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorManager.textPrimary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildTypeChip(
                title: 'General',
                subtitle: 'Basic medical',
                icon: Icons.translate_rounded,
                isSelected: _interpreterType == 'general',
                onTap: () {
                  setState(() {
                    _interpreterType = 'general';
                    _selectedMedicalSection = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeChip(
                title: 'Specialist',
                subtitle: 'Advanced Medical',
                icon: Icons.medical_services_rounded,
                isSelected: _interpreterType == 'specialist',
                onTap: () {
                  setState(() {
                    _interpreterType = 'specialist';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? ColorManager.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ColorManager.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? ColorManager.primary.withOpacity(0.25)
                      : Colors.black.withOpacity(0.03),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Colors.white.withOpacity(0.2)
                        : ColorManager.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : ColorManager.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isSelected
                              ? Colors.white.withOpacity(0.8)
                              : ColorManager.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalSectionsCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Medical Specialty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: _medicalSections.length,
              itemBuilder: (context, index) {
                final section = _medicalSections[index];
                final isSelected = _selectedMedicalSection == section['key'];
                final color = section['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMedicalSection = section['key'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? color.withOpacity(0.15)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? color : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FaIcon(
                            section['icon'] as IconData,
                            size: 20,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section['label'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? color : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Call Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorManager.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildCallTypeButton(
                  title: 'Voice Call',
                  icon: Icons.phone_rounded,
                  isSelected: _callType == 'voice',
                  onTap: () => setState(() => _callType = 'voice'),
                ),
              ),
              Expanded(
                child: _buildCallTypeButton(
                  title: 'Video Call',
                  icon: Icons.videocam_rounded,
                  isSelected: _callType == 'video',
                  onTap: () => setState(() => _callType = 'video'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCallTypeButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color:
                  isSelected
                      ? ColorManager.primary
                      : ColorManager.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected
                        ? ColorManager.primary
                        : ColorManager.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      child: FloatingActionButton.extended(
        onPressed: _canStartRequest ? _startRequest : null,
        backgroundColor:
            _canStartRequest ? ColorManager.primary : const Color(0xFFCBD5E1),
        elevation: _canStartRequest ? 8 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              color: _canStartRequest ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Text(
              'Find Interpreter',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color:
                    _canStartRequest ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: _canStartRequest ? Colors.white : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _startRequest() {
    if (!_canStartRequest) return;

    String? specialization;
    String? medicalSection;

    if (_interpreterType == 'specialist' && _selectedMedicalSection != null) {
      final section = _medicalSections.firstWhere(
        (s) => s['key'] == _selectedMedicalSection,
        orElse:
            () => {
              'label': _selectedMedicalSection,
              'key': _selectedMedicalSection,
            },
      );
      specialization = section['label'] as String?;
      medicalSection =
          section['key'] as String?; // e.g., 'neurology', 'cardiology'
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => RequestWaitingView(
              fromLanguageId: _selectedFromLanguage!.id.toString(),
              toLanguageId: _selectedToLanguage!.id.toString(),
              specialization: specialization,
              urgency: 'Normal',
              callType: _callType,
              interpreterType: _interpreterType, // 'general' or 'specialist'
              medicalSection: medicalSection, // e.g., 'neurology', 'cardiology'
            ),
      ),
    );
  }
}
