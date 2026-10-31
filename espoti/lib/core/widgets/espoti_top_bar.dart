import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import 'espoti_logo.dart';

/// Standard, responsive Top Bar with overflow protection and active navigation menu.
class EspotiTopBar extends StatelessWidget {
  final String? title;
  final Widget? trailing;

  const EspotiTopBar({
    super.key,
    this.title,
    this.trailing,
  });

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.background,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.home, color: AppColors.primaryBrown),
                title: const Text('Inicio', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event, color: AppColors.primaryBrown),
                title: const Text('Reuniones', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, AppRoutes.meetings);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group, color: AppColors.primaryBrown),
                title: const Text('Amigos', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, AppRoutes.friends);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: AppColors.primaryBrown),
                title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacementNamed(context, AppRoutes.profile);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.analytics, color: AppColors.orange),
                title: const Text(
                  'Analíticas BQ Tipo 5',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBrown),
                ),
                subtitle: const Text('Tasa de aceptación y patrones de recomendación'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppRoutes.bq5Analytics);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Flexible(
          child: EspotiLogo(height: AppDimensions.logoSizeSmall),
        ),
        if (title != null) ...[
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBrown,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        trailing ??
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.primaryBrown),
              tooltip: 'Menú principal',
              onPressed: () => _showMenu(context),
            ),
      ],
    );
  }
}
