import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/analytics_service.dart';
import '../../core/widgets/attendee_avatars.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../models/meeting.dart';

/// "Create a meeting" (3): resultado de la votación del organizador.
///
/// Dos casos según los argumentos que manda el paso 2:
///  - Sin invitados (o votación ya cerrada): muestra el lugar ganador.
///  - Votación abierta ('votingOpen' = true): el lugar mostrado es solo el
///    voto del organizador; se indica cuántos votaron, quiénes faltan y que la
///    reunión queda pendiente hasta que voten todos.
class WinningPlacePage extends StatefulWidget {
  const WinningPlacePage({super.key});

  @override
  State<WinningPlacePage> createState() => _WinningPlacePageState();
}

class _WinningPlacePageState extends State<WinningPlacePage> {
  bool _resultRecorded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resultRecorded) return;
    _resultRecorded = true;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map ? routeArgs : const <dynamic, dynamic>{};
    final meetingId = args['meetingId'] as String?;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AnalyticsService()
        ..stepCompleted(MeetingPlanningStep.result, meetingId: meetingId)
        ..planningCompleted(meetingId: meetingId);
    });
  }

  void _handleNavTap(BuildContext context, EspotiNavItem item) {
    switch (item) {
      case EspotiNavItem.home:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case EspotiNavItem.meetings:
        Navigator.pushReplacementNamed(context, AppRoutes.meetings);
        break;
      case EspotiNavItem.profile:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        break;
      case EspotiNavItem.createMeeting:
        break;
      case EspotiNavItem.friends:
        Navigator.pushReplacementNamed(context, AppRoutes.friends);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map ? routeArgs : const <dynamic, dynamic>{};
    final placeName = args['placeName'] as String?;
    // The place chosen in step 2 (no invented data when it is missing).
    final winner = Meeting(
      placeName: placeName ?? 'No place selected',
      timeLabel: args['placeCategory'] as String? ?? '',
      distanceLabel: args['placeDetail'] as String? ?? '',
    );
    final day = (args['day'] as String?)?.trim() ?? '';
    final time = (args['time'] as String?)?.trim() ?? '';
    final transit = args['transitMode'] as String?;
    final choseOffline = args['offline'] == true;
    final votingOpen = args['votingOpen'] == true;
    final names = (args['participantNames'] as List?)?.cast<String>() ?? const ['You'];
    final voted = args['votedCount'] as int?;
    final required = args['requiredCount'] as int?;
    final missing = (args['missingNames'] as List?)?.cast<String>() ?? const [];
    final meetingId = args['meetingId'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.paddingM),
              const EspotiTopBar(),
              const SizedBox(height: AppDimensions.paddingL),
              if (choseOffline) ...[
                const Text(
                  'You are offline: your choice is saved on this phone and will be shared with the group when you reconnect.',
                  style: TextStyle(fontSize: 12, color: AppColors.orange),
                ),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              const Text(AppStrings.youWillMeet, style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              AttendeeAvatars(count: names.length),
              const SizedBox(height: AppDimensions.paddingS),
              Text(names.join(', '),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: AppDimensions.paddingS),
              Text('Date: ${day.isEmpty ? 'Not specified' : day}',
                  style: const TextStyle(fontSize: 15, color: AppColors.text)),
              Text('Time: ${time.isEmpty ? 'Not specified' : time}',
                  style: const TextStyle(fontSize: 15, color: AppColors.text)),
              if (transit != null)
                Text('Getting there: $transit',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: AppDimensions.paddingL),
              Text(votingOpen ? 'Your vote:' : AppStrings.winningPlace,
                  style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              _PlaceCard(meeting: winner),
              if (votingOpen) ...[
                const SizedBox(height: AppDimensions.paddingM),
                _VotingStatus(
                  voted: voted,
                  required: required,
                  missing: missing,
                ),
                if (meetingId != null)
                  TextButton.icon(
                    icon: const Icon(Icons.how_to_vote_outlined),
                    label: const Text('See voting'),
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.meetingVoting,
                        arguments: {'meetingId': meetingId}),
                  ),
              ],
              const SizedBox(height: AppDimensions.paddingL),
              Center(
                child: SizedBox(
                  width: 160,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    // Planning finished: go to the list where the saved
                    // meeting now appears (clears the planning screens).
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, AppRoutes.meetings, (route) => false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrown,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.createMeeting,
        onItemSelected: (item) => _handleNavTap(context, item),
      ),
    );
  }
}

const _sectionTitleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 16,
  color: AppColors.text,
);

/// Estado de una votación abierta: votos emitidos y quién falta.
class _VotingStatus extends StatelessWidget {
  final int? voted;
  final int? required;
  final List<String> missing;

  const _VotingStatus({required this.voted, required this.required, required this.missing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Voting in progress',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          if (voted != null && required != null)
            Text('$voted of $required participants have voted.',
                style: const TextStyle(color: AppColors.text)),
          if (missing.isNotEmpty)
            Text('Waiting for: ${missing.join(', ')}',
                style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text(
            'The meeting stays pending until everyone votes. The most voted place wins; on a tie, the organizer\'s choice wins.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Simple (non-interactive) card for the chosen place.
class _PlaceCard extends StatelessWidget {
  final Meeting meeting;

  const _PlaceCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: const Color(0xFFD9D9D9)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppDimensions.radiusM),
            ),
            child: Container(
              width: 80,
              height: 80,
              color: AppColors.orange50,
              child: const Icon(Icons.place_outlined,
                  color: AppColors.primaryBrown),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.placeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.text),
                  ),
                  if (meeting.timeLabel.isNotEmpty)
                    Text(meeting.timeLabel,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (meeting.distanceLabel.isNotEmpty)
                    Text(
                      meeting.distanceLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
