import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';

/// Displays the Espoti logo image asset.

class EspotiLogo extends StatelessWidget {
  final double height;
  final bool light;

  const EspotiLogo({super.key, this.height = 70, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logo,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() {
    final color = light ? AppColors.white : AppColors.primaryBrown;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pets, color: color, size: height * 0.55),
        Text(
          'Espoti',
          style: TextStyle(
            fontFamily: 'IrishGrover',
            fontSize: height * 0.32,
            color: color,
          ),
        ),
      ],
    );
  }
}
