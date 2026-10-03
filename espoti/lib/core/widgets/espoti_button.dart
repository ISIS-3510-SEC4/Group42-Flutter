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
  final bool isLoading;

  const EspotiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EspotiButtonVariant.primary,
    this.width,
    this.isLoading = false,
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
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
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
