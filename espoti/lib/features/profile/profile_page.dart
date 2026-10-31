import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_top_bar.dart';
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
    return ValueListenableBuilder<AppUser>(
      valueListenable: UserService().userNotifier,
      builder: (context, user, _) {
        final displayName =
            user.firstName.isNotEmpty ? user.firstName : user.name;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppDimensions.paddingM),
                  const EspotiTopBar(),
                  const SizedBox(height: AppDimensions.paddingM),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Hello $displayName',
                          style: Theme.of(context).textTheme.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.paddingS),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.editProfile);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBrown,
                          side: const BorderSide(color: AppColors.primaryBrown),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusPill),
                          ),
                        ),
                        child: const Text(AppStrings.editProfile,
                            style: TextStyle(fontSize: 12)),
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
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
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
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.ios_share,
                                    size: 14, color: AppColors.orange),
                              ],
                            ),
                            Text(
                              user.location,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  _InfoRow(
                      label: AppStrings.preferences,
                      value: user.preferences.join(', ')),
                  const SizedBox(height: AppDimensions.paddingS),
                  _InfoRow(
                      label: AppStrings.maxRadius,
                      value: '${user.maxRadiusKm} km'),
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
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                SizedBox(height: 2),
                Text(
                  AppStrings.inviteCoffeeSubtitle,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
            child:
                const Text(AppStrings.support, style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Direct link to BQ5 Analytics
        ListTile(
          onTap: () => Navigator.pushNamed(context, AppRoutes.bq5Analytics),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.analytics_outlined, color: AppColors.orange),
          title: const Text(
            'Analíticas BQ Tipo 5',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Tasa de aceptación y patrones de recomendación',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ),
        const Divider(height: 1, color: AppColors.mauve30),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline, color: AppColors.primaryBrown),
          title: const Text(AppStrings.privacy, style: TextStyle(color: AppColors.text)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_on_outlined, color: AppColors.primaryBrown),
          title: const Text(AppStrings.location, style: TextStyle(color: AppColors.text)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_none, color: AppColors.primaryBrown),
          title: const Text(AppStrings.notification, style: TextStyle(color: AppColors.text)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.favorite_border, color: AppColors.primaryBrown),
          title: const Text(AppStrings.helpUsGrow, style: TextStyle(color: AppColors.text)),
        ),
        ListTile(
          onTap: () async {
            await AuthService().signOut();
            await UserService().clearUser();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.welcome,
                (route) => false,
              );
            }
          },
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout, color: AppColors.primaryBrown),
          title: const Text(AppStrings.logOut, style: TextStyle(color: AppColors.text)),
        ),
      ],
    );
  }
}
