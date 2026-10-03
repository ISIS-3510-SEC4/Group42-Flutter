import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class PreferenceSelector extends StatelessWidget {
  final List<String> selectedPreferences;
  final ValueChanged<List<String>> onPreferencesChanged;
  final String? errorText;

  const PreferenceSelector({
    super.key,
    required this.selectedPreferences,
    required this.onPreferencesChanged,
    this.errorText,
  });

  static const List<String> availableOptions = [
    'Walk',
    'Eat',
    'Coffee',
    'Study',
    'Party',
    'Sports',
    'Cinema',
    'Gaming',
  ];

  void _togglePreference(String option) {
    final updated = List<String>.from(selectedPreferences);
    if (updated.contains(option)) {
      updated.remove(option);
    } else {
      updated.add(option);
    }
    onPreferencesChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferencias:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableOptions.map((option) {
            final isSelected = selectedPreferences.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => _togglePreference(option),
              selectedColor: AppColors.orange,
              backgroundColor: AppColors.mauve30,
              checkmarkColor: AppColors.white,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.white : AppColors.text,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                side: BorderSide(
                  color: isSelected ? AppColors.orange : Colors.transparent,
                ),
              ),
            );
          }).toList(),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
