import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/espoti_top_bar.dart';
import 'meeting_planning_time_service.dart';

class MeetingPlanningTimePage extends StatefulWidget {
  const MeetingPlanningTimePage({super.key});

  @override
  State<MeetingPlanningTimePage> createState() =>
      _MeetingPlanningTimePageState();
}

class _MeetingPlanningTimePageState extends State<MeetingPlanningTimePage> {
  final MeetingPlanningTimeService _service = MeetingPlanningTimeService();
  Stream<MeetingPlanningTimeSnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final userId = AuthService().currentUser?.uid;
    _stream = userId == null ? null : _service.watchForUser(userId);
  }

  void _retry() {
    setState(_startListening);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingL,
                AppDimensions.paddingM,
                AppDimensions.paddingL,
                AppDimensions.paddingS,
              ),
              child: EspotiTopBar(
                title: 'Planning time',
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.primaryBrown),
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.mauve30),
            Expanded(
              child: _stream == null
                  ? const _Message(
                      icon: Icons.account_circle_outlined,
                      message: 'Sign in to see your planning times.',
                    )
                  : StreamBuilder<MeetingPlanningTimeSnapshot>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primaryBrown));
                        }
                        if (snapshot.hasError) {
                          return _Message(
                            icon: Icons.error_outline,
                            message: 'Planning times could not be loaded.',
                            onRetry: _retry,
                          );
                        }
                        final data = snapshot.data;
                        if (data == null) {
                          return const _Message(
                            icon: Icons.bar_chart_outlined,
                            message: 'No planning times are available yet.',
                          );
                        }
                        return _PlanningTimeContent(data: data);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningTimeContent extends StatelessWidget {
  const _PlanningTimeContent({required this.data});

  final MeetingPlanningTimeSnapshot data;

  static const Map<String, String> _labels = {
    'details': 'Details',
    'vote': 'Voting',
    'result': 'Result',
  };

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final maximumMs = summary.averageMsByStep.values.fold<int>(
      0,
      (maximum, value) => value > maximum ? value : maximum,
    );
    final longest = summary.longestSteps;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Which step of the meeting planning process takes you the longest?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryBrown,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            'Average time per completed step',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          for (final step in MeetingPlanningTimeSummary.steps)
            _StepTimeBar(
              label: _labels[step]!,
              durationMs: summary.averageMsByStep[step] ?? 0,
              fraction: maximumMs == 0
                  ? 0
                  : (summary.averageMsByStep[step] ?? 0) / maximumMs,
            ),
          const SizedBox(height: AppDimensions.paddingM),
          if (!summary.hasData)
            const _Message(
              icon: Icons.hourglass_empty,
              message:
                  'Complete a meeting planning flow to start building this chart.',
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.orange),
              ),
              child: Text(
                longest.length == 1
                    ? 'You spend the most time on ${_labels[longest.first]} '
                        '(${_formatDuration(summary.averageMsByStep[longest.first] ?? 0)} on average).'
                    : 'You spend the most time on ${longest.map((step) => _labels[step]).join(' and ')} '
                        '(tied average).',
                style: const TextStyle(
                  color: AppColors.primaryBrown,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (data.fromCache) ...[
            const SizedBox(height: AppDimensions.paddingM),
            const Text(
              'Showing saved data. New times will appear when you reconnect.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepTimeBar extends StatelessWidget {
  const _StepTimeBar({
    required this.label,
    required this.durationMs,
    required this.fraction,
  });

  final String label;
  final int durationMs;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                durationMs == 0 ? '—' : _formatDuration(durationMs),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingS),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: AppColors.mauve30,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.mauve30),
            const SizedBox(height: AppDimensions.paddingM),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(int milliseconds) {
  if (milliseconds < 1000) return '$milliseconds ms';
  if (milliseconds < 60000) {
    return '${(milliseconds / 1000).toStringAsFixed(1)} s';
  }
  return '${(milliseconds / 60000).toStringAsFixed(1)} min';
}
