import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Generic widget to display a row of circular avatars for meeting attendees.
class AttendeeAvatars extends StatelessWidget {
  final int count;
  final double size;

  const AttendeeAvatars({
    super.key,
    this.count = 3,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap en lugar de Row: con muchos participantes los avatares bajan de
    // línea en vez de desbordar la pantalla horizontalmente.
    return Wrap(
      spacing: AppDimensions.paddingS,
      runSpacing: AppDimensions.paddingS,
      children: List.generate(count, (_) {
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mauve30,
          ),
          child: Icon(Icons.person,
              color: AppColors.primaryBrown, size: size * 0.5),
        );
      }),
    );
  }
}
