import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/analytics_service.dart';
import 'analytics_dashboard_widgets.dart';

const _stepLabels = {
  MeetingPlanningStep.details: '1. Details',
  MeetingPlanningStep.vote: '2. Vote',
  MeetingPlanningStep.result: '3. Winning place',
};

const _reasonLabels = {
  PlanningAbandonReason.leftScreen: 'Left the screen',
  PlanningAbandonReason.navigation: 'Went to another section',
  PlanningAbandonReason.appClosed: 'Closed the app',
  PlanningAbandonReason.restarted: 'Started another attempt',
};

/// Sección de la BQ de abandono (VV2) dentro del tablero único.
/// [data] lo calcula aggregatePlanningAbandonment a partir de los eventos
/// PLANNING_* leídos en tiempo real de Firestore.
class PlanningAbandonmentContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const PlanningAbandonmentContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    const i = AnalyticsData.intOf;
    final sample = i(data['sampleCount']);
    final completed = i(data['completedAttempts']);
    final abandoned = i(data['abandonedAttempts']);
    final open = i(data['openAttempts']);
    final byStep = AnalyticsData.mapOf(data['byStep']);
    final reasons = AnalyticsData.mapOf(data['abandonReasons']);
    final peak = AnalyticsData.mapOf(data['peakAbandonStep']);
    final updated = AnalyticsData.updatedAtLabel(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuestionBanner(
          label: 'Abandonment BQ (Viva Voce 2)',
          question:
              'At which step do users most frequently abandon the meeting planning process?',
        ),
        const SizedBox(height: AppDimensions.paddingM),
        if (sample == 0) ...[
          DashboardMessage(
            icon: Icons.hourglass_empty,
            message: open > 0
                ? 'There are $open attempts in progress, but none has finished yet.'
                : 'No planning attempts have been recorded yet.',
          ),
        ] else ...[
          // Antes era un GridView con proporción fija (childAspectRatio 2.2):
          // la altura de cada celda no alcanzaba para número + etiqueta y se
          // desbordaba ~11 px. Ahora son dos filas cuya altura se ajusta al
          // contenido.
          StatTileGrid(tiles: [
            StatTile(label: 'Finished attempts', value: '$sample'),
            StatTile(
                label: 'Completion rate',
                value: percent(AnalyticsData.doubleOf(data['completionRate']))),
            StatTile(label: 'Completed', value: '$completed'),
            StatTile(label: 'Abandoned', value: '$abandoned'),
          ]),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            peak.isEmpty
                ? 'No finished attempt was abandoned.'
                : 'Step with the most abandonments: ${_stepLabels[peak['step']] ?? peak['step']} '
                    '(${i(peak['abandoned'])} attempts, '
                    '${percent(AnalyticsData.doubleOf(peak['abandonRate']))} of those who reached it).',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          const SectionHeader('Abandonments by step'),
          BarList(rows: [
            for (final step in _stepLabels.keys)
              (
                _stepLabels[step]!,
                i(AnalyticsData.mapOf(byStep[step])['abandoned']),
                '${i(AnalyticsData.mapOf(byStep[step])['abandoned'])}',
              ),
          ]),
          const SectionHeader('Abandonment rate (of those who reached the step)'),
          BarList(
            max: 1,
            rows: [
              for (final step in _stepLabels.keys)
                (
                  '${_stepLabels[step]!} (${i(AnalyticsData.mapOf(byStep[step])['reached'])})',
                  AnalyticsData.doubleOf(
                      AnalyticsData.mapOf(byStep[step])['abandonRate']),
                  percent(AnalyticsData.doubleOf(
                      AnalyticsData.mapOf(byStep[step])['abandonRate'])),
                ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SectionHeader('How it was abandoned'),
            BarList(rows: [
              for (final entry in reasons.entries)
                (_reasonLabels[entry.key] ?? entry.key, i(entry.value), '${i(entry.value)}'),
            ]),
          ],
        ],
        const SizedBox(height: AppDimensions.paddingL),
        Text(
          [
            if (open > 0) '$open attempts in progress are not included in the rates.',
            if (i(data['ignoredEvents']) > 0)
              '${i(data['ignoredEvents'])} events ignored because of incomplete data.',
            if (updated != null) 'Updated: $updated',
          ].join('\n'),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
