import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';


enum EspotiNavItem { home, meetings, createMeeting, friends, profile }


class EspotiBottomNavigation extends StatelessWidget {
  final EspotiNavItem currentItem;
  final ValueChanged<EspotiNavItem> onItemSelected;

  const EspotiBottomNavigation({
    super.key,
    required this.currentItem,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.bottomNavHeight + 12,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: AppDimensions.bottomNavHeight,
              decoration: const BoxDecoration(
                color: AppColors.primaryBrown,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusL),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavIcon(
                    icon: Icons.home,
                    label: AppStrings.navHome,
                    selected: currentItem == EspotiNavItem.home,
                    onTap: () => onItemSelected(EspotiNavItem.home),
                  ),
                  _NavIcon(
                    icon: Icons.location_on,
                    label: AppStrings.navMeetings,
                    selected: currentItem == EspotiNavItem.meetings,
                    onTap: () => onItemSelected(EspotiNavItem.meetings),
                  ),
                  // Empty space reserved for the floating "+" button above.
                  const SizedBox(width: AppDimensions.bottomNavFabSize),
                  _NavIcon(
                    icon: Icons.groups,
                    label: AppStrings.navFriends,
                    selected: currentItem == EspotiNavItem.friends,
                    onTap: () => onItemSelected(EspotiNavItem.friends),
                  ),
                  _NavIcon(
                    icon: Icons.person,
                    label: AppStrings.navProfile,
                    selected: currentItem == EspotiNavItem.profile,
                    onTap: () => onItemSelected(EspotiNavItem.profile),
                  ),
                ],
              ),
            ),
          ),
          // We need to add 
          GestureDetector(
            onTap: () => onItemSelected(EspotiNavItem.createMeeting),
            child: Container(
              width: AppDimensions.bottomNavFabSize,
              height: AppDimensions.bottomNavFabSize,
              decoration: const BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.add, color: AppColors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
