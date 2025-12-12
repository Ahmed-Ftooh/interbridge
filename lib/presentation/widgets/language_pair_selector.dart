import 'package:flutter/material.dart';
import 'package:interbridge/data/models/language.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

/// Reusable language pair selector with searchable bottom sheet.
class LanguagePairSelector extends StatefulWidget {
  /// All languages (used if fromLanguages/toLanguages are not provided)
  final List<Language> languages;

  /// Optional: Separate list of languages for "from" selection
  final List<Language>? fromLanguages;

  /// Optional: Separate list of languages for "to" selection
  final List<Language>? toLanguages;

  final Language? fromLanguage;
  final Language? toLanguage;
  final ValueChanged<Language?> onFromChanged;
  final ValueChanged<Language?> onToChanged;
  final bool enableSwap;
  final String fromLabel;
  final String toLabel;

  const LanguagePairSelector({
    super.key,
    required this.languages,
    this.fromLanguages,
    this.toLanguages,
    required this.fromLanguage,
    required this.toLanguage,
    required this.onFromChanged,
    required this.onToChanged,
    this.enableSwap = true,
    this.fromLabel = 'From',
    this.toLabel = 'To',
  });

  @override
  State<LanguagePairSelector> createState() => _LanguagePairSelectorState();
}

class _LanguagePairSelectorState extends State<LanguagePairSelector> {
  void _openPicker(bool isFrom) {
    // Use specific language list if provided, otherwise use the general list
    final languageList =
        isFrom
            ? (widget.fromLanguages ?? widget.languages)
            : (widget.toLanguages ?? widget.languages);

    if (languageList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Languages not loaded yet.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';
        List<Language> filtered = languageList;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void applyFilter(String value) {
              setModalState(() {
                searchQuery = value.trim();
                filtered =
                    languageList.where((lang) {
                      return lang.name.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      );
                    }).toList();
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppSize.s20),
                      topRight: Radius.circular(AppSize.s20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(
                          top: AppSize.s12,
                          bottom: AppSize.s8,
                        ),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ColorManager.greyMedium,
                          borderRadius: BorderRadius.circular(AppSize.s2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSize.s20,
                          AppSize.s8,
                          AppSize.s8,
                          AppSize.s12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select ${isFrom ? widget.fromLabel : widget.toLabel} Language',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSize.s20,
                          vertical: AppSize.s8,
                        ),
                        child: TextField(
                          onChanged: applyFilter,
                          decoration: InputDecoration(
                            hintText: 'Search language...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              borderSide: BorderSide(
                                color: ColorManager.greyMedium,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              borderSide: BorderSide(
                                color: ColorManager.greyMedium,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSize.s20),
                              borderSide: BorderSide(
                                color: ColorManager.primary2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSize.s16,
                              vertical: AppSize.s10,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                      Expanded(
                        child:
                            filtered.isEmpty
                                ? Center(
                                  child: Text(
                                    'No languages found for "$searchQuery"',
                                  ),
                                )
                                : ListView.builder(
                                  controller: scrollController,
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final language = filtered[index];
                                    final bool isSelected =
                                        isFrom
                                            ? widget.fromLanguage?.id ==
                                                language.id
                                            : widget.toLanguage?.id ==
                                                language.id;
                                    return ListTile(
                                      leading: Icon(
                                        Icons.language,
                                        color:
                                            isSelected
                                                ? ColorManager.primary2
                                                : ColorManager.textSecondary,
                                      ),
                                      title: Text(
                                        language.name,
                                        style: TextStyle(
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          color:
                                              isSelected
                                                  ? ColorManager.primary2
                                                  : ColorManager.textPrimary,
                                        ),
                                      ),
                                      trailing:
                                          isSelected
                                              ? Icon(
                                                Icons.check_circle,
                                                color: ColorManager.primary2,
                                                size: 20,
                                              )
                                              : null,
                                      onTap: () {
                                        if (isFrom) {
                                          widget.onFromChanged(language);
                                          // Clear opposing if same
                                          if (widget.toLanguage?.id ==
                                              language.id) {
                                            widget.onToChanged(null);
                                          }
                                        } else {
                                          widget.onToChanged(language);
                                          if (widget.fromLanguage?.id ==
                                              language.id) {
                                            widget.onFromChanged(null);
                                          }
                                        }
                                        Navigator.of(context).pop();
                                      },
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSize.s24,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSize.s16),
        side: BorderSide(color: ColorManager.greyLight),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSize.s20),
        child: Column(
          children: [
            _LanguageSelectTile(
              label: widget.fromLabel,
              language: widget.fromLanguage?.name,
              onTap: () => _openPicker(true),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSize.s8),
              child: Center(
                child: IconButton(
                  onPressed:
                      widget.enableSwap &&
                              (widget.fromLanguage != null ||
                                  widget.toLanguage != null)
                          ? () {
                            widget.onFromChanged(widget.toLanguage);
                            widget.onToChanged(widget.fromLanguage);
                          }
                          : null,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColorManager.primary2.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.swap_vert,
                      color: ColorManager.primary2,
                      size: 24,
                    ),
                  ),
                  tooltip: 'Swap Languages',
                ),
              ),
            ),
            _LanguageSelectTile(
              label: widget.toLabel,
              language: widget.toLanguage?.name,
              onTap: () => _openPicker(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSelectTile extends StatelessWidget {
  final String label;
  final String? language;
  final VoidCallback onTap;

  const _LanguageSelectTile({
    required this.label,
    required this.language,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSize.s16,
          vertical: AppSize.s12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: ColorManager.greyMedium),
          borderRadius: BorderRadius.circular(AppSize.s12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.language, color: ColorManager.primary2, size: 20),
            const SizedBox(width: AppSize.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorManager.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    language ?? 'Select language',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          language != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                      color:
                          language != null
                              ? ColorManager.textPrimary
                              : ColorManager.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: ColorManager.textSecondary),
          ],
        ),
      ),
    );
  }
}
