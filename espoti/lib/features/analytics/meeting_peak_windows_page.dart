import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../models/transit_mode.dart';
import 'analytics_dashboard_widgets.dart';

/// Sección de la BQ tipo 4 (VV3) dentro del tablero único.
/// [data] lo calcula aggregateMeetingPeakWindows a partir de los eventos
/// MEETING_CREATED leídos en tiempo real de Firestore.
class MeetingPeakWindowsContent extends StatefulWidget {
  final Map<String, dynamic> data;
  const MeetingPeakWindowsContent({super.key, required this.data});

  @override
  State<MeetingPeakWindowsContent> createState() =>
      _MeetingPeakWindowsContentState();
}

class _MeetingPeakWindowsContentState extends State<MeetingPeakWindowsContent> {
  /// Medio de transporte elegido en los chips (estado solo de la vista).
  String? _selectedMode;

  @override
  Widget build(BuildContext context) => _content(widget.data);

  Widget _content(Map<String, dynamic> data) {
    const i = AnalyticsData.intOf;
    final sample = i(data['sampleCount']);
    final byMode = AnalyticsData.mapOf(data['byTransitMode']);
    final peaks = AnalyticsData.mapOf(data['peaks']);
    final modes = byMode.keys.toList()
      ..sort((a, b) => i(AnalyticsData.mapOf(byMode[b])['total'])
          .compareTo(i(AnalyticsData.mapOf(byMode[a])['total'])));
    final selected =
        modes.contains(_selectedMode) ? _selectedMode! : (modes.isEmpty ? null : modes.first);
    final updated = AnalyticsData.updatedAtLabel(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuestionBanner(
          label: 'BQ Type 4 (Viva Voce 3)',
          question:
              'What are the peak days and time windows during which groups organize meetings, by transit mode?',
        ),
        const SizedBox(height: AppDimensions.paddingM),
        if (sample == 0 || selected == null)
          const DashboardMessage(
            icon: Icons.hourglass_empty,
            message: 'No meetings have been created yet.',
          )
        else ...[
          Text('$sample meetings analyzed',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
          const SectionHeader('Meetings by transit mode'),
          BarList(rows: [
            for (final mode in modes)
              (
                _modeLabel(mode),
                i(AnalyticsData.mapOf(byMode[mode])['total']),
                '${i(AnalyticsData.mapOf(byMode[mode])['total'])}',
              ),
          ]),
          const SizedBox(height: AppDimensions.paddingM),
          Wrap(
            spacing: AppDimensions.paddingS,
            children: [
              for (final mode in modes)
                ChoiceChip(
                  label: Text(_modeLabel(mode)),
                  selected: mode == selected,
                  onSelected: (_) => setState(() => _selectedMode = mode),
                ),
            ],
          ),
          ..._modeDetail(
            AnalyticsData.mapOf(byMode[selected]),
            AnalyticsData.mapOf(peaks[selected]),
          ),
        ],
        const SizedBox(height: AppDimensions.paddingL),
        Text(
          [
            'Local time of the device that created the meeting.',
            if (i(data['ignoredEvents']) > 0)
              '${i(data['ignoredEvents'])} events ignored (incomplete or duplicated).',
            if (updated != null) 'Updated: $updated',
          ].join('\n'),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  List<Widget> _modeDetail(Map<String, dynamic> mode, Map<String, dynamic> peaks) {
    String peakText(String key, String Function(String) label) {
      final peak = AnalyticsData.mapOf(peaks[key]);
      final value = peak['key'];
      if (value is! String) return 'No data';
      return '${label(value)} (${AnalyticsData.intOf(peak['count'])})';
    }

    return [
      const SectionHeader('Peaks'),
      _PeakRow('Day most meetings are organized', peakText('peakCreatedDay', _dayLabel)),
      _PeakRow('Window most meetings are organized', peakText('peakCreatedWindow', _windowLabel)),
      _PeakRow('Day + window', peakText('peakCreatedDayAndWindow', _dayWindowLabel)),
      _PeakRow('Most scheduled day', peakText('peakScheduledDay', _dayLabel)),
      _PeakRow('Most scheduled window', peakText('peakScheduledWindow', _windowLabel)),
      const SectionHeader('Created by day'),
      _counts(AnalyticsData.mapOf(mode['createdByDay']), _days, _dayLabel),
      const SectionHeader('Created by time window'),
      _counts(AnalyticsData.mapOf(mode['createdByWindow']), _windows, _windowLabel),
      const SectionHeader('Scheduled by day'),
      _counts(AnalyticsData.mapOf(mode['scheduledByDay']), _days, _dayLabel),
      const SectionHeader('Scheduled by time window'),
      _counts(AnalyticsData.mapOf(mode['scheduledByWindow']), _windows, _windowLabel),
    ];
  }

  Widget _counts(Map<String, dynamic> counts, List<String> order,
      String Function(String) label) {
    if (counts.isEmpty) {
      return const Text('No data',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
    }
    return BarList(rows: [
      for (final key in order)
        (
          label(key),
          AnalyticsData.intOf(counts[key]),
          '${AnalyticsData.intOf(counts[key])}',
        ),
    ]);
  }

  static String _modeLabel(String wire) =>
      TransitMode.fromWire(wire)?.label ??
      (wire == 'UNSPECIFIED' ? 'Not specified' : wire);

  static const _days = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
  ];
  static const _dayNames = {
    'MONDAY': 'Monday', 'TUESDAY': 'Tuesday', 'WEDNESDAY': 'Wednesday',
    'THURSDAY': 'Thursday', 'FRIDAY': 'Friday', 'SATURDAY': 'Saturday',
    'SUNDAY': 'Sunday',
  };
  static const _windows = [
    'EARLY_MORNING', 'MORNING', 'MIDDAY', 'AFTERNOON', 'EVENING', 'NIGHT',
  ];
  // Same windows as MeetingTimeWindow (meeting_creation_tracker.dart).
  static const _windowNames = {
    'EARLY_MORNING': 'Early morning (5-8)', 'MORNING': 'Morning (8-12)',
    'MIDDAY': 'Midday (12-14)', 'AFTERNOON': 'Afternoon (14-18)',
    'EVENING': 'Evening (18-22)', 'NIGHT': 'Night (22-5)',
  };

  static String _dayLabel(String key) => _dayNames[key] ?? key;
  static String _windowLabel(String key) => _windowNames[key] ?? key;
  static String _dayWindowLabel(String key) {
    final split = key.indexOf('_');
    if (split < 0) return key;
    return '${_dayLabel(key.substring(0, split))} · ${_windowLabel(key.substring(split + 1))}';
  }
}

class _PeakRow extends StatelessWidget {
  final String label;
  final String value;
  const _PeakRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          ],
        ),
      );
}
