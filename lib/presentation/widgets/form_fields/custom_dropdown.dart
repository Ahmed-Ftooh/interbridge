import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';
import 'package:interbridge/presentation/resources/values_manager.dart';

/// Reusable dropdown widget to eliminate code duplication across the app
class CustomDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final IconData icon;
  final bool enabled;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Remove duplicates from items list
    final uniqueItems = items.toSet().toList();

    // Validate selected value
    final validValue =
        value != null && uniqueItems.contains(value) ? value : null;

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
        Container(
          decoration: BoxDecoration(
            color:
                enabled
                    ? Colors.white
                    : ColorManager.greyLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppSize.s12),
            border: Border.all(color: ColorManager.greyMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSize.s12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              hint: Text('Select $label'),
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: ColorManager.primary2),
              items:
                  uniqueItems.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: ColorManager.primary2,
                            size: AppSize.s20,
                          ),
                          const SizedBox(width: AppSize.s12),
                          Text(item),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}
