import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

/// Reusable multi-select dropdown widget to eliminate code duplication
class CustomMultiSelectDropdown extends StatelessWidget {
  final String label;
  final List<String> selectedItems;
  final List<String> allItems;
  final Function(List<String>) onChanged;
  final IconData icon;
  final bool enabled;

  const CustomMultiSelectDropdown({
    super.key,
    required this.label,
    required this.selectedItems,
    required this.allItems,
    required this.onChanged,
    required this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Remove duplicates from all items list
    final uniqueAllItems = allItems.toSet().toList();

    // Filter selected items to only include valid ones
    final validSelectedItems =
        selectedItems.where((item) => uniqueAllItems.contains(item)).toList();

    // If there are invalid selected items, update the parent (once)
    if (validSelectedItems.length != selectedItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChanged(validSelectedItems);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppSize.s14,
            fontWeight: FontWeight.w600,
            color: ColorManager.textPrimary,
          ),
        ),
        const SizedBox(height: AppSize.s8),
        InkWell(
          onTap:
              enabled
                  ? () => _showMultiSelectDialog(
                    context,
                    label,
                    validSelectedItems,
                    uniqueAllItems,
                    onChanged,
                  )
                  : null,
          child: Container(
            padding: const EdgeInsets.all(AppSize.s12),
            decoration: BoxDecoration(
              color:
                  enabled
                      ? Colors.white
                      : ColorManager.greyLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppSize.s12),
              border: Border.all(color: ColorManager.greyMedium),
            ),
            child: Row(
              children: [
                Icon(icon, color: ColorManager.primary2, size: AppSize.s20),
                const SizedBox(width: AppSize.s12),
                Expanded(
                  child: Text(
                    validSelectedItems.isEmpty
                        ? 'Select $label'
                        : validSelectedItems.join(', '),
                    style: TextStyle(
                      color:
                          validSelectedItems.isEmpty
                              ? ColorManager.textSecondary
                              : ColorManager.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: ColorManager.primary2),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMultiSelectDialog(
    BuildContext context,
    String label,
    List<String> selectedItems,
    List<String> allItems,
    Function(List<String>) onChanged,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select $label'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  final isSelected = selectedItems.contains(item);

                  return CheckboxListTile(
                    title: Text(item),
                    value: isSelected,
                    activeColor: ColorManager.primary2,
                    onChanged: (value) {
                      List<String> newSelection;
                      if (value == true) {
                        newSelection = [...selectedItems, item];
                      } else {
                        newSelection =
                            selectedItems.where((i) => i != item).toList();
                      }
                      onChanged(newSelection);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: ColorManager.primary2),
                ),
              ),
            ],
          ),
    );
  }
}
