import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/avatar_group.dart';
import '../../core/widgets/espoti_button.dart';

class MeetingDetailPage extends StatelessWidget {
  const MeetingDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryBrown),
        title: const Text(
          AppStrings.detail,
          style: TextStyle(color: AppColors.primaryBrown),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.map, size: 64, color: AppColors.orange50),
                  // Fake pins
                  Positioned(
                    top: 50,
                    left: 80,
                    child: _MapPin(avatarUrl: 'https://i.pravatar.cc/100?img=1'),
                  ),
                  Positioned(
                    bottom: 60,
                    right: 90,
                    child: _MapPin(avatarUrl: 'https://i.pravatar.cc/100?img=2'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            
            // Details
            const Text(
              'Restaurant Los Andes',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.orange, size: 20),
                const Text(
                  ' 4.0',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: AppDimensions.paddingL),
                const Icon(Icons.timer, color: AppColors.primaryBrown, size: 20),
                const Text(
                  ' 30 Minutes',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
            const Text(
              '3km from your location',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            
            // Participants
            const Text(
              'They are also going:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Row(
              children: [
                const Expanded(
                  child: AvatarGroup(
                    avatarUrls: [
                      'https://i.pravatar.cc/100?img=1',
                      'https://i.pravatar.cc/100?img=2',
                      'https://i.pravatar.cc/100?img=3',
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.orange50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.primaryBrown),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingL),
            
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: EspotiButton(
                label: 'Take a photo',
                variant: EspotiButtonVariant.primary,
                onPressed: () {},
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            SizedBox(
              width: double.infinity,
              child: EspotiButton(
                label: 'Cancel',
                variant: EspotiButtonVariant.secondary,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final String avatarUrl;
  const _MapPin({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
      ),
    );
  }
}
