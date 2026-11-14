import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../services/meeting_voting_service.dart';
import 'espoti_logo.dart';

/// Menú hamburguesa único de la app.
///
/// Todas las pantallas lo abren con [EspotiMenu.show] (desde [EspotiTopBar]
/// o desde [EspotiMenuButton] en las pantallas con AppBar), así abrir, cerrar
/// y elegir una opción se comporta igual en todas partes:
///  - Las secciones principales (Home, Meetings, Friends, Profile) limpian la
///    pila de navegación, para no apilar pantallas repetidas.
///  - Las demás opciones (crear reunión, votaciones, sensor, analíticas) se
///    abren encima y se vuelve con "atrás".
///  - Si ya estás en esa pantalla, el menú solo se cierra.
///  - [onBeforeNavigate] permite que la pantalla actual registre algo antes de
///    salir (por ejemplo, el abandono del flujo de planificación).
class EspotiMenu {
  EspotiMenu._();

  static const Set<String> _sections = {
    AppRoutes.home,
    AppRoutes.meetings,
    AppRoutes.friends,
    AppRoutes.profile,
  };

  static Future<void> show(BuildContext context, {VoidCallback? onBeforeNavigate}) {
    final current = ModalRoute.of(context)?.settings.name;

    void go(BuildContext sheetContext, String route) {
      Navigator.pop(sheetContext); // cierra el menú
      if (route == current) return;
      onBeforeNavigate?.call();
      if (_sections.contains(route)) {
        Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
      } else {
        Navigator.pushNamed(context, route);
      }
    }

    Widget item(BuildContext ctx, IconData icon, String label, String route,
            {String? subtitle, Widget? trailing}) =>
        ListTile(
          leading: Icon(icon, color: AppColors.primaryBrown),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: trailing,
          selected: route == current,
          selectedTileColor: AppColors.orange50,
          onTap: () => go(ctx, route),
        );

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppColors.background,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          // Como máximo el 85 % de la pantalla; el resto se desplaza.
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item(ctx, Icons.home, 'Home', AppRoutes.home),
                item(ctx, Icons.event, 'Meetings', AppRoutes.meetings),
                item(ctx, Icons.add_circle_outline, 'Create meeting',
                    AppRoutes.createMeeting),
                ValueListenableBuilder<VotingOverview>(
                  valueListenable: MeetingVotingService.instance.overview,
                  builder: (_, overview, __) => item(
                    ctx,
                    Icons.how_to_vote_outlined,
                    'Pending votes',
                    AppRoutes.pendingVotes,
                    trailing: overview.pendingMyVote == 0
                        ? null
                        : CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.orange,
                            child: Text('${overview.pendingMyVote}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.white)),
                          ),
                  ),
                ),
                item(ctx, Icons.group, 'Friends', AppRoutes.friends),
                item(ctx, Icons.person, 'My profile', AppRoutes.profile),
                item(ctx, Icons.sensors, 'Motion sensor', AppRoutes.motionSensor,
                    subtitle: 'Live accelerometer reading'),
                const Divider(),
                item(ctx, Icons.analytics, 'Analytics BQ Type 5',
                    AppRoutes.bq5Analytics,
                    subtitle: 'Recommendation acceptance rate'),
                item(ctx, Icons.insights, 'Analytics dashboard',
                    AppRoutes.analyticsDashboard,
                    subtitle: 'Planning abandonment + meeting peaks (live)'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de menú para pantallas con AppBar (por ejemplo, el detalle).
class EspotiMenuButton extends StatelessWidget {
  final VoidCallback? onBeforeNavigate;
  const EspotiMenuButton({super.key, this.onBeforeNavigate});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.menu, color: AppColors.primaryBrown),
        tooltip: 'Main menu',
        onPressed: () => EspotiMenu.show(context, onBeforeNavigate: onBeforeNavigate),
      );
}

/// Standard, responsive Top Bar with overflow protection and the app menu.
class EspotiTopBar extends StatelessWidget {
  final String? title;
  final Widget? trailing;

  /// Se ejecuta antes de navegar desde el menú (ver [EspotiMenu.show]).
  final VoidCallback? onBeforeNavigate;

  const EspotiTopBar({
    super.key,
    this.title,
    this.trailing,
    this.onBeforeNavigate,
  });

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
        // El menú está siempre; si la pantalla pasa un botón propio (por
        // ejemplo "volver" en las analíticas), se muestran los dos.
        if (trailing != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            trailing!,
            EspotiMenuButton(onBeforeNavigate: onBeforeNavigate),
          ])
        else
          EspotiMenuButton(onBeforeNavigate: onBeforeNavigate),
      ],
    );
  }
}
