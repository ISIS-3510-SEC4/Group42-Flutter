import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Reusable labeled text field matching the soft, rounded, filled inputs
/// shown in the Login/Register screenshots.
class EspotiTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final String? errorText;
  final String? hintText;
  final TextInputType keyboardType;
  final int? maxLength;
  final double? letterSpacing;
  final bool showCounter;

  const EspotiTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.errorText,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.letterSpacing,
    this.showCounter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
            letterSpacing: letterSpacing ?? 0.2,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingS),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          buildCounter: (maxLength != null && showCounter)
              ? (context, {required currentLength, required isFocused, maxLength}) =>
                  Text(
                    '$currentLength / $maxLength',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  )
              : null,
          style: TextStyle(
            color: AppColors.text,
            letterSpacing: letterSpacing ?? 0.3,
          ),
          decoration: InputDecoration(
            counterText: showCounter ? null : '',
            errorText: errorText,
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              letterSpacing: letterSpacing ?? 0.3,
            ),
            filled: true,
            fillColor: AppColors.orange50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingM,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
      ],
    );
  }
}
