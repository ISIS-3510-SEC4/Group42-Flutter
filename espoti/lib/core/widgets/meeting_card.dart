import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'avatar_group.dart';

class MeetingCard extends StatelessWidget {
  final String placeName;
  final String line1;
  final String line2;
  final List<String> avatarUrls;
  final String extraParticipantsLabel;
  final double? rating;
  final bool compact;
  final VoidCallback? onDetail;
  final VoidCallback? onTakePhoto;
  final Widget? bottomWidget;
  final Color? backgroundColor;

  const MeetingCard({
    super.key,
    required this.placeName,
    required this.line1,
    this.line2 = '',
    this.avatarUrls = const [],
    this.extraParticipantsLabel = '',
    this.rating,
    this.compact = false,
    this.onDetail,
    this.onTakePhoto,
    this.bottomWidget,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.orange50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primaryBrown, size: 18),
              const SizedBox(width: AppDimensions.paddingXS),
              Expanded(
                child: Text(
                  placeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rating != null) ...[
                const Icon(Icons.star, color: AppColors.orange, size: 16),
                Text(' ${rating!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            line1,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (line2.isNotEmpty)
            Text(
              line2,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          const SizedBox(height: AppDimensions.paddingS),
          AvatarGroup(
            avatarUrls: avatarUrls,
            extraLabel: extraParticipantsLabel,
          ),
          if (!compact && (onDetail != null || onTakePhoto != null)) ...[
            const SizedBox(height: AppDimensions.paddingM),
            Row(
              children: [
                if (onDetail != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDetail,
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                      label: const Text('Detail'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBrown,
                        side: const BorderSide(color: AppColors.primaryBrown),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                        ),
                      ),
                    ),
                  ),
                if (onDetail != null && onTakePhoto != null)
                  const SizedBox(width: AppDimensions.paddingS),
                if (onTakePhoto != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onTakePhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Take a photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrown,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (bottomWidget != null) ...[
            const SizedBox(height: AppDimensions.paddingM),
            bottomWidget!,
          ]
        ],
      ),
    );
  }
}
