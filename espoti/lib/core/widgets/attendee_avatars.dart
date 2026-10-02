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
    return Row(
      children: List.generate(count, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index < count - 1 ? AppDimensions.paddingS : 0,
          ),
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mauve30,
            ),
            child: Icon(Icons.person,
                color: AppColors.primaryBrown, size: size * 0.5),
          ),
        );
      }),
    );
  }
}
