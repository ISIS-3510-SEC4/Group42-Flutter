import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../offline/sync_service.dart';

// Banner que informa al usuario sobre el estado de conexión y sincronización.
// Se oculta cuando todos los cambios están sincronizados.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios en el estado de sincronización.
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.status,
      builder: (context, s, _) {
        final String? message;

        // Muestra un mensaje si existen operaciones que no se pudieron sincronizar.
        if (s.failed > 0) {
          message = s.failed == 1
              ? '1 cambio no se pudo sincronizar.'
              : '${s.failed} cambios no se pudieron sincronizar.';

        // Informa cuando no hay conexión y existen cambios pendientes.
        } else if (!s.online) {
          message = s.pending > 0
              ? 'Sin conexión · ${s.pending} cambio(s) se enviarán al reconectar.'
              : 'Sin conexión · mostrando datos guardados.';

        // Informa cuando se están enviando cambios a Firestore.
        } else if (s.syncing) {
          message = 'Sincronizando…';

        // Informa cuando todavía existen cambios pendientes.
        } else if (s.pending > 0) {
          message = '${s.pending} cambio(s) pendientes de sincronizar.';

        // No muestra el banner cuando no hay nada que informar.
        } else {
          message = null;
        }

        if (message == null) return const SizedBox.shrink();

        // Evita solicitar nuevos intentos mientras hay una sincronización activa.
        final canRetry = !s.syncing;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM, vertical: 6),
          decoration: BoxDecoration(
            // Utiliza rojo para indicar errores y el color de acento para otros estados.
            color: s.failed > 0 ? Colors.red.shade50 : AppColors.accent1,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          child: Row(
            children: [
              // Cambia el icono según el estado de conexión.
              Icon(
                s.online ? Icons.cloud_upload_outlined : Icons.cloud_off,
                size: 18,
                color: AppColors.primaryBrown,
              ),
              const SizedBox(width: AppDimensions.paddingS),

              // Muestra el mensaje adaptándose al espacio disponible.
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.text),
                ),
              ),

              // Permite reintentar las operaciones fallidas o pendientes.
              if (canRetry)
                TextButton(
                  onPressed: s.failed > 0
                      ? SyncService.instance.retryFailed
                      : SyncService.instance.syncNow,
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        );
      },
    );
  }
}