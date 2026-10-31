import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../models/transit_mode.dart';

/// "How will you get there?" choice for the create-meeting form.
class TransitModeSelector extends StatelessWidget {
  final TransitMode? selected;
  final ValueChanged<TransitMode> onChanged;
  final String? errorText;

  const TransitModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  static const _icons = {
    TransitMode.publicTransit: Icons.directions_bus,
    TransitMode.driving: Icons.directions_car,
    TransitMode.walking: Icons.directions_walk,
    TransitMode.cycling: Icons.directions_bike,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How will you get there?',
          style: TextStyle(fontSize: 15, color: AppColors.text),
        ),
        const SizedBox(height: AppDimensions.paddingS),
        Wrap(
          spacing: AppDimensions.paddingS,
          runSpacing: AppDimensions.paddingS,
          children: [
            for (final mode in TransitMode.values)
              ChoiceChip(
                avatar: Icon(
                  _icons[mode],
                  size: 18,
                  color: selected == mode ? AppColors.white : AppColors.primaryBrown,
                ),
                label: Text(mode.label),
                selected: selected == mode,
                showCheckmark: false,
                selectedColor: AppColors.primaryBrown,
                backgroundColor: AppColors.orange50,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: selected == mode ? AppColors.white : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => onChanged(mode),
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(errorText!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          ),
        const SizedBox(height: AppDimensions.paddingM),
      ],
    );
  }
}
