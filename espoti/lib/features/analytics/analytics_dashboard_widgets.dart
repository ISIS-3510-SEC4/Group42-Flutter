import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/widgets/espoti_top_bar.dart';
import 'analytics_result_view_model.dart';

/// Scaffold shared by the analytics dashboards (BQ abandono and BQ tipo 4):
/// it observes an [AnalyticsResultViewModel] and shows loading, a real empty
/// state, an error state with retry, or [builder] with the aggregate.
class AnalyticsDashboardScaffold extends StatelessWidget {
  final String title;
  final AnalyticsResultViewModel viewModel;
  final String emptyMessage;
  final Widget Function(BuildContext, Map<String, dynamic>) builder;

  const AnalyticsDashboardScaffold({
    super.key,
    required this.title,
    required this.viewModel,
    required this.emptyMessage,
    required this.builder,
  });

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
                title: title,
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
                listenable: viewModel,
                builder: (context, _) => switch (viewModel.status) {
                  AnalyticsResultStatus.loading => const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryBrown)),
                  AnalyticsResultStatus.empty =>
                    DashboardMessage(icon: Icons.inbox_outlined, message: emptyMessage),
                  AnalyticsResultStatus.error => DashboardMessage(
                      icon: Icons.error_outline,
                      message: viewModel.error ?? 'Error',
                      onRetry: viewModel.retry,
                    ),
                  AnalyticsResultStatus.ready => SingleChildScrollView(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      child: builder(context, viewModel.data!),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const DashboardMessage(
      {super.key, required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppDimensions.paddingM),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Question banner at the top of a dashboard.
class QuestionBanner extends StatelessWidget {
  final String label;
  final String question;
  const QuestionBanner({super.key, required this.label, required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.mauve30.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBrown)),
          const SizedBox(height: 4),
          Text(question, style: const TextStyle(fontSize: 13, color: AppColors.text)),
        ],
      ),
    );
  }
}

/// One headline number (stat tile).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  const StatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.mauve30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El número se reduce si no cabe y la etiqueta usa como máximo dos
          // líneas, para que la tarjeta nunca se desborde.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
          ),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Indicadores en dos columnas cuya altura se adapta al contenido
/// (IntrinsicHeight iguala la altura de las dos tarjetas de cada fila).
class StatTileGrid extends StatelessWidget {
  final List<StatTile> tiles;
  const StatTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : AppDimensions.paddingS),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: AppDimensions.paddingS),
              Expanded(
                  child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }
}

class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
            top: AppDimensions.paddingL, bottom: AppDimensions.paddingS),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
      );
}

/// Horizontal bar list: one magnitude per row, single hue, value label at the
/// end of each bar. Rows keep the given order (e.g. Monday..Sunday).
class BarList extends StatelessWidget {
  final List<(String label, num value, String valueLabel)> rows;
  final num? max;

  const BarList({super.key, required this.rows, this.max});

  @override
  Widget build(BuildContext context) {
    final top = max ??
        rows.fold<num>(0, (m, r) => r.$2 > m ? r.$2 : m);
    return Column(
      children: [
        for (final (label, value, valueLabel) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(label,
                      style: const TextStyle(fontSize: 12, color: AppColors.text),
                      maxLines: 2),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: top <= 0 ? 0.0 : (value / top).clamp(0.0, 1.0).toDouble(),
                      minHeight: 12,
                      backgroundColor: AppColors.mauve30.withValues(alpha: 0.3),
                      color: AppColors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingS),
                SizedBox(
                  width: 64,
                  child: Text(valueLabel,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String percent(double rate) => '${(rate * 100).toStringAsFixed(1)} %';
