import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Displays a row of small overlapping circular avatars
class AvatarGroup extends StatelessWidget {
  final List<String> avatarUrls;
  final String extraLabel;
  final double size;

  const AvatarGroup({
    super.key,
    required this.avatarUrls,
    this.extraLabel = '',
    this.size = AppDimensions.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: size,
          width: avatarUrls.isEmpty
              ? 0
              : size + (avatarUrls.length - 1) * AppDimensions.avatarOverlap,
          child: Stack(
            children: [
              for (int i = 0; i < avatarUrls.length; i++)
                Positioned(
                  left: i * AppDimensions.avatarOverlap,
                  child: _Avatar(url: avatarUrls[i], size: size),
                ),
            ],
          ),
        ),
        if (extraLabel.isNotEmpty) ...[
          const SizedBox(width: AppDimensions.paddingS),
          Flexible(
            child: Text(
              extraLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double size;

  const _Avatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
        color: AppColors.mauve30,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.person,
          size: size * 0.6,
          color: AppColors.primaryBrown,
        ),
      ),
    );
  }
}
