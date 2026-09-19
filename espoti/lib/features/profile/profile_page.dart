import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../models/user.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _handleNavTap(BuildContext context, EspotiNavItem item) {
    switch (item) {
      case EspotiNavItem.home:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case EspotiNavItem.meetings:
        Navigator.pushReplacementNamed(context, AppRoutes.meetings);
        break;
      case EspotiNavItem.profile:
        break; 
      case EspotiNavItem.createMeeting:
        Navigator.pushReplacementNamed(context, AppRoutes.createMeeting);
        break; 
      case EspotiNavItem.friends:
        Navigator.pushReplacementNamed(context, AppRoutes.friends);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const user = mockUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.paddingM),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EspotiLogo(height: AppDimensions.logoSizeSmall),
                  Icon(Icons.menu, color: AppColors.primaryBrown),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.helloJulian, style: Theme.of(context).textTheme.headlineMedium),
                  OutlinedButton(
                    
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBrown,
                      side: const BorderSide(color: AppColors.primaryBrown),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      ), 
                    ),
                    child: const Text(AppStrings.editProfile, style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.mauve30,
                    child: ClipOval(
                      child: Image.network(
                        user.avatarUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.person,
                          size: 36,
                          color: AppColors.primaryBrown,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.yourCode,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Row(
                          children: [
                            Text(
                              user.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.ios_share, size: 14, color: AppColors.orange),
                          ],
                        ),
                        Text(
                          user.location,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingL),
              _InfoRow(label: AppStrings.preferences, value: user.preferences.join(', ')),
              const SizedBox(height: AppDimensions.paddingS),
              _InfoRow(label: AppStrings.maxRadius, value: '${user.maxRadiusKm} km'),
              const SizedBox(height: AppDimensions.paddingL),
              const _InviteCoffeeCard(),
              const SizedBox(height: AppDimensions.paddingL),
              const _SettingsList(),
              const SizedBox(height: AppDimensions.paddingL),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.profile,
        onItemSelected: (item) => _handleNavTap(context, item),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: AppColors.text),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: value, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _InviteCoffeeCard extends StatelessWidget {
  const _InviteCoffeeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.orange50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      child: Row(
        children: [
          const Icon(Icons.coffee, color: AppColors.primaryBrown, size: 28),
          const SizedBox(width: AppDimensions.paddingM),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.inviteCoffee,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                SizedBox(height: 2),
                Text(
                  AppStrings.inviteCoffeeSubtitle,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrown,
              foregroundColor: AppColors.white,
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
            ),
            child: const Text(AppStrings.support, style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList();

  static const _items = [
    (AppStrings.privacy, Icons.lock_outline),
    (AppStrings.location, Icons.location_on_outlined),
    (AppStrings.notification, Icons.notifications_none),
    (AppStrings.helpUsGrow, Icons.favorite_border),
    (AppStrings.logOut, Icons.logout),
    (AppStrings.deleteAccount, Icons.delete_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items
          .map(
            (item) => ListTile(
              
              onTap: null,
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.$2, color: AppColors.primaryBrown),
              title: Text(item.$1, style: const TextStyle(color: AppColors.text)),
            ),
          )
          .toList(),
    );
  }
}
