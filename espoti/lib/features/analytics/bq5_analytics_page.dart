import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/widgets/espoti_top_bar.dart';
import 'analytics_dashboard_widgets.dart';
import 'bq5_analytics_view_model.dart';

/// Screen for Business Question Type 5:
/// "How do user's location preferences and interaction patterns affect the
/// acceptance rate of meeting point recommendations?"
class Bq5AnalyticsPage extends StatefulWidget {
  const Bq5AnalyticsPage({super.key});

  @override
  State<Bq5AnalyticsPage> createState() => _Bq5AnalyticsPageState();
}

class _Bq5AnalyticsPageState extends State<Bq5AnalyticsPage> {
  final _vm = Bq5AnalyticsViewModel()..start();

  @override
  void dispose() {
    _vm.dispose();
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL,
                vertical: AppDimensions.paddingM,
              ),
              child: EspotiTopBar(
                title: 'Analytics',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          color: AppColors.primaryBrown),
                      tooltip: 'Refresh',
                      onPressed: _vm.refresh,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.primaryBrown),
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.mauve30),
            Expanded(
              child: AnimatedBuilder(
                animation: _vm,
                builder: (context, _) {
                  if (_vm.status == Bq5AnalyticsStatus.loading &&
                      !_vm.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryBrown),
                    );
                  }
                  if (_vm.status == Bq5AnalyticsStatus.error && !_vm.hasData) {
                    return DashboardMessage(
                      icon: Icons.error_outline,
                      message: _vm.error ?? 'Could not load metrics.',
                      onRetry: _vm.retry,
                    );
                  }
                  final total =
                      (_vm.data['totalDecisions'] as num?)?.toInt() ?? 0;
                  if (!_vm.hasData || total == 0) {
                    return const DashboardMessage(
                      icon: Icons.bar_chart_outlined,
                      message:
                          'No recommendation decisions recorded yet.\nVote on a place to view metrics.',
                    );
                  }
                  return _buildMetrics(_vm.data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(Map<String, dynamic> data) {
    final rate = (data['overallAcceptanceRate'] as num?)?.toDouble() ?? 0.0;
    final total = (data['totalDecisions'] as num?)?.toInt() ?? 0;
    final accepted = (data['totalAccepted'] as num?)?.toInt() ?? 0;
    final rejected = (data['totalRejected'] as num?)?.toInt() ?? 0;
    final byPref = (data['byPreference'] as Map<String, dynamic>?) ?? {};
    final byPattern =
        (data['byInteractionPattern'] as Map<String, dynamic>?) ?? {};

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      children: [
        const QuestionBanner(
          label: 'Business Question Type 5',
          question:
              "How do user's location preferences and interaction patterns affect the acceptance rate of meeting point recommendations?",
        ),
        const SizedBox(height: AppDimensions.paddingL),
        StatTileGrid(tiles: [
          StatTile(
              label: 'Overall Acceptance Rate',
              value: '${rate.toStringAsFixed(1)}%'),
          StatTile(label: 'Total Recommendations', value: '$total'),
          StatTile(label: 'Accepted', value: '$accepted'),
          StatTile(label: 'Rejected', value: '$rejected'),
        ]),
        const SectionHeader('Acceptance by Location Preference'),
        if (byPref.isEmpty)
          const Text('No preference data yet.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontStyle: FontStyle.italic))
        else
          BarList(
            max: 100,
            rows: [
              for (final e in byPref.entries)
                (
                  e.key,
                  (e.value['rate'] as num?)?.toDouble() ?? 0.0,
                  '${((e.value['rate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}% (${e.value['accepted']}/${e.value['total']})',
                ),
            ],
          ),
        const SectionHeader('Acceptance by Interaction Pattern'),
        if (byPattern.isEmpty)
          const Text('No interaction pattern data yet.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontStyle: FontStyle.italic))
        else
          BarList(
            max: 100,
            rows: [
              for (final e in byPattern.entries)
                (
                  _cleanPattern(e.key),
                  (e.value['rate'] as num?)?.toDouble() ?? 0.0,
                  '${((e.value['rate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}% (${e.value['accepted']}/${e.value['total']})',
                ),
            ],
          ),
      ],
    );
  }

  String _cleanPattern(String key) => switch (key) {
        'MAP_EXPANDED' => 'Map Inspection',
        'DETAILS_VIEWED' => 'Details Viewed',
        'BUDGET_FILTERED' => 'Budget Filtered',
        'DIRECT_SELECT' => 'Direct Selection',
        _ => key,
      };
}
