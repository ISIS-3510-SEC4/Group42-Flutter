import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../models/user.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _searchController = TextEditingController();

  void _handleNavTap(EspotiNavItem item) {
    switch (item) {
      case EspotiNavItem.home:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case EspotiNavItem.meetings:
        Navigator.pushReplacementNamed(context, AppRoutes.meetings);
        break;
      case EspotiNavItem.profile:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        break;
      case EspotiNavItem.createMeeting:
        Navigator.pushReplacementNamed(context, AppRoutes.createMeeting);
        break;
      case EspotiNavItem.friends:
        break; 
    }
  }

  void _handleSearchSubmit(String value) {
    if (value.trim().isEmpty) return;
    print('Buscando código: $value');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const user = mockUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.paddingL,
                AppDimensions.paddingM,
                AppDimensions.paddingL,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EspotiLogo(height: AppDimensions.logoSizeSmall),
                  Icon(Icons.menu, color: AppColors.primaryBrown),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.mauve30,
                          backgroundImage: NetworkImage(user.avatarUrl),
                        ),
                        const SizedBox(width: AppDimensions.paddingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                              ),
                              Row(
                                children: [
                                  const Text(
                                    AppStrings.yourCode,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.code,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy, size: 14, color: AppColors.orange),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    
                    const Text(
                      'Search new friends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _handleSearchSubmit,
                      decoration: InputDecoration(
                        hintText: 'Enter the code',
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: AppColors.textSecondary),
                          onPressed: () => _handleSearchSubmit(_searchController.text),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          borderSide: const BorderSide(color: AppColors.primaryBrown, width: 1),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppDimensions.paddingS),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleSearchSubmit(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrown,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          ),
                        ),
                        child: const Text('Contacts'),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    
                    const Text(
                      'Your friends:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppDimensions.paddingM,
                      crossAxisSpacing: AppDimensions.paddingM,
                      children: const [
                        _FriendItem(name: 'Ana', avatarUrl: 'https://i.pravatar.cc/100?img=1'),
                        _FriendItem(name: 'Raúl', avatarUrl: 'https://i.pravatar.cc/100?img=2'),
                        _FriendItem(name: 'Sofía', avatarUrl: 'https://i.pravatar.cc/100?img=3'),
                        _FriendItem(name: 'Diego', avatarUrl: 'https://i.pravatar.cc/100?img=4'),
                        _FriendItem(name: 'Laura', avatarUrl: 'https://i.pravatar.cc/100?img=5'),
                        _FriendItem(name: 'Carlos', avatarUrl: 'https://i.pravatar.cc/100?img=6'),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.friends,
        onItemSelected: _handleNavTap,
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final String name;
  final String avatarUrl;

  const _FriendItem({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.mauve30,
          backgroundImage: NetworkImage(avatarUrl),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 12, color: AppColors.text),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}