import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Visual style variants for [EspotiButton].
enum EspotiButtonVariant { primary, secondary }


class EspotiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final EspotiButtonVariant variant;
  final double? width;

  const EspotiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EspotiButtonVariant.primary,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = variant == EspotiButtonVariant.primary
        ? AppColors.orange
        : AppColors.primaryBrown;

    return SizedBox(
      width: width ?? double.infinity,
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
