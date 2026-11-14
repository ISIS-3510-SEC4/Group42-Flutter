import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/widgets/espoti_top_bar.dart';
import 'analytics_dashboard_view_model.dart';
import 'analytics_dashboard_widgets.dart';
import 'meeting_peak_windows_page.dart';
import 'planning_abandonment_page.dart';

/// Tablero único de analítica: las dos BQ en una sola pantalla.
///
///  - BQ de abandono (VV2): ¿en qué paso se abandona la planificación?
///  - BQ tipo 4 (VV3): días y franjas pico por medio de transporte.
///
/// Todo sale de una sola base de datos (Firestore, `analytics_events`) y se
/// calcula en la app en tiempo real ([AnalyticsDashboardViewModel]); también
/// se puede actualizar bajo demanda con "Refresh now". No depende de scripts
/// ni de archivos.
class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  final AnalyticsDashboardViewModel _viewModel = AnalyticsDashboardViewModel()
    ..start();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingL,
                  AppDimensions.paddingM, AppDimensions.paddingL, AppDimensions.paddingS),
              child: EspotiTopBar(
                title: 'Analytics dashboard',
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primaryBrown),
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.mauve30),
            Expanded(
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_viewModel.status) {
      case DashboardStatus.loading:
        return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBrown));
      case DashboardStatus.error:
        return DashboardMessage(
          icon: Icons.error_outline,
          message: _viewModel.error ?? 'Error',
          onRetry: _viewModel.retry,
        );
      case DashboardStatus.ready:
        return RefreshIndicator(
          onRefresh: _viewModel.refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            children: [
              _LiveHeader(viewModel: _viewModel),
              const SizedBox(height: AppDimensions.paddingL),
              PlanningAbandonmentContent(data: _viewModel.planningAbandonment),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingL),
                child: Divider(color: AppColors.mauve30),
              ),
              MeetingPeakWindowsContent(data: _viewModel.meetingPeakWindows),
              const SizedBox(height: AppDimensions.paddingL),
            ],
          ),
        );
    }
  }
}

/// Cabecera: fuente de los datos, modo en vivo, hora de la última
/// actualización y botón para actualizar bajo demanda.
class _LiveHeader extends StatelessWidget {
  final AnalyticsDashboardViewModel viewModel;
  const _LiveHeader({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final updated = viewModel.updatedAt;
    final time = updated == null
        ? '—'
        : '${updated.hour.toString().padLeft(2, '0')}:'
            '${updated.minute.toString().padLeft(2, '0')}:'
            '${updated.second.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.mauve30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            viewModel.fromCache ? Icons.cloud_off : Icons.sensors,
            color: viewModel.fromCache ? AppColors.orange : AppColors.primaryBrown,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.fromCache
                      ? 'Offline: showing the last data received'
                      : 'Live from Firestore (analytics_events)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.text),
                ),
                Text(
                  '${viewModel.eventCount} events · updated $time',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: viewModel.refreshing ? null : viewModel.refresh,
            child: viewModel.refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Refresh now'),
          ),
        ],
      ),
    );
  }
}
