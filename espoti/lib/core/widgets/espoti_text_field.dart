import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

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
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.inputFormatters,
    this.onSubmitted,
    this.textInputAction,
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
        // Límite de caracteres: el TextField no deja escribir más de
        // [maxLength] (MaxLengthEnforcement por defecto) y, al llegar al
        // límite, se muestra un aviso explícito en lugar del texto de ayuda.
        // Se escucha el controller para actualizar el aviso mientras se escribe.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final atLimit =
                maxLength != null && value.text.characters.length >= maxLength!;
            return TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              readOnly: readOnly,
              onTap: onTap,
              maxLength: maxLength,
              inputFormatters: inputFormatters,
              onSubmitted: onSubmitted,
              textInputAction: textInputAction,
              buildCounter: (maxLength != null && (showCounter || atLimit))
                  ? (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      Text(
                        '$currentLength / $maxLength',
                        style: TextStyle(
                          fontSize: 11,
                          color: atLimit ? AppColors.orange : AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      )
                  : null,
              style: TextStyle(
                color: AppColors.text,
                letterSpacing: letterSpacing ?? 0.3,
              ),
              decoration: InputDecoration(
                counterText: (showCounter || atLimit) ? null : '',
                errorText: errorText,
                helperText: errorText == null && atLimit
                    ? 'Character limit reached ($maxLength)'
                    : null,
                helperStyle: const TextStyle(color: AppColors.orange),
                hintText: hintText,
                suffixIcon: suffixIcon,
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
            );
          },
        ),
        const SizedBox(height: AppDimensions.paddingM),
      ],
    );
  }
}
