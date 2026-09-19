
import 'package:espoti/core/constants/app_assets.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBrown,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXL,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Image.asset(
                AppAssets.espotiImage,
                height: 180,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: AppDimensions.paddingL),

              const EspotiLogo(
                height: AppDimensions.logoSizeLarge,
                light: true,
              ),

              const SizedBox(height: AppDimensions.paddingL),

              Text(
                AppStrings.tagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                    ),
              ),

              const Spacer(flex: 2),

              EspotiButton(
                label: AppStrings.login,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.login),
              ),

              const SizedBox(height: AppDimensions.paddingM),

              EspotiButton(
                label: AppStrings.register,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.register),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

