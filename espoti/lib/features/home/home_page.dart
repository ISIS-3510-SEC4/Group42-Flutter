import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/user_service.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../core/widgets/meeting_card.dart';
import '../../core/widgets/section_title.dart';
import '../../models/meeting.dart';
import '../../models/meeting_record.dart';
import '../../models/user.dart';
import '../../core/services/meeting_voting_service.dart';
import '../meetings/meetings_view_model.dart';
import '../meetings/pending_votes_page.dart';

/// Home: greeting plus the user's real upcoming and previous meetings, read
/// through [MeetingsViewModel] (same source as the Meetings screen). Empty
/// states instead of sample meetings.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MeetingsViewModel _meetings = MeetingsViewModel()..start();

  @override
  void initState() {
    super.initState();
    // Sin notificaciones: al entrar a Home se revisan las votaciones y se
    // cierran las que ya estén completas (ver MeetingVotingService).
    MeetingVotingService.instance.refresh();
  }

  @override
  void dispose() {
    _meetings.dispose();
    super.dispose();
  }

  void _handleNavTap(BuildContext context, EspotiNavItem item) {
    switch (item) {
      case EspotiNavItem.home:
        break;
      case EspotiNavItem.meetings:
        Navigator.pushReplacementNamed(context, AppRoutes.meetings);
        break;
      case EspotiNavItem.profile:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        break;
      case EspotiNavItem.createMeeting:
        // A single route: pushing it twice opened two planning attempts.
        Navigator.pushNamed(context, AppRoutes.createMeeting);
        break;
      case EspotiNavItem.friends:
        Navigator.pushReplacementNamed(context, AppRoutes.friends);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: AppDimensions.paddingM),
              ValueListenableBuilder<AppUser>(
                valueListenable: UserService().userNotifier,
                builder: (context, user, _) {
                  final displayName =
                      user.firstName.isNotEmpty ? user.firstName : user.name;
                  return Text(
                    displayName.isEmpty ? 'Hello!' : 'Hello, $displayName',
                    style: Theme.of(context).textTheme.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              const Text(
                AppStrings.tagline,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              // Reuniones que esperan el voto del usuario (con botón "Vote").
              const PendingVotesSection(),
              const SizedBox(height: AppDimensions.paddingM),
              EspotiButton(
                label: AppStrings.createMeeting,
                variant: EspotiButtonVariant.secondary,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.createMeeting),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              const SectionTitle(title: AppStrings.nextMeetings),
              const SizedBox(height: AppDimensions.paddingS),
              ListenableBuilder(
                listenable: _meetings,
                builder: (context, _) => _NextMeetings(viewModel: _meetings),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              SectionTitle(
                title: AppStrings.meetingHistory,
                trailingLabel: AppStrings.previousEvents,
                onTrailingTap: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.meetings),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              ListenableBuilder(
                listenable: _meetings,
                builder: (context, _) => _History(viewModel: _meetings),
              ),
              const SizedBox(height: AppDimensions.paddingL),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.home,
        onItemSelected: (item) => _handleNavTap(context, item),
      ),
    );
  }
}

void _openMeeting(BuildContext context, MeetingRecord meeting) =>
    Navigator.pushNamed(context, AppRoutes.meetingDetail,
        arguments: {'meetingId': meeting.id});

/// Estado vacío claro (ícono + título + explicación) para las secciones de
/// Home cuando no hay reuniones.
class _HomeEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _HomeEmptyState(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.mauve30),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(message,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HomeMessage extends StatelessWidget {
  final String text;
  const _HomeMessage(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
        child: Text(text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
}

class _NextMeetings extends StatelessWidget {
  final MeetingsViewModel viewModel;
  const _NextMeetings({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.loading) return const LinearProgressIndicator();
    if (viewModel.error != null) return _HomeMessage(viewModel.error!);
    final meetings = viewModel.upcomingSoonestFirst;
    if (meetings.isEmpty) {
      return const _HomeEmptyState(
        icon: Icons.event_busy,
        title: 'No upcoming meetings',
        message: 'You don\'t have any upcoming meetings. Tap "Create new meeting" to plan one.',
      );
    }
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: meetings.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.paddingM),
        itemBuilder: (context, index) {
          final meeting = meetings[index];
          return SizedBox(
            width: 170,
            child: MeetingCard(
              placeName: meeting.title,
              line1: meeting.whenLabel,
              line2: meeting.isVotingOpen
                  ? 'Voting in progress'
                  : viewModel.isInvited(meeting)
                      ? 'You are invited'
                      : meeting.transitMode?.label ?? '',
              extraParticipantsLabel: meeting.inviteeNames.join(', '),
              compact: true,
              onDetail: () => _openMeeting(context, meeting),
            ),
          );
        },
      ),
    );
  }
}

class _History extends StatelessWidget {
  final MeetingsViewModel viewModel;
  const _History({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.loading) return const SizedBox.shrink();
    final previous = viewModel.byStatus(MeetingStatus.previous).take(4).toList();
    if (previous.isEmpty) {
      return const _HomeEmptyState(
        icon: Icons.history,
        title: 'No meeting history',
        message: 'You don\'t have any meeting history yet',
      );
    }
    return Column(
      children: [
        for (final meeting in previous)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: AppColors.primaryBrown),
            title: Text(meeting.title,
                style: const TextStyle(color: AppColors.text)),
            subtitle: Text(meeting.whenLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            onTap: () => _openMeeting(context, meeting),
          ),
      ],
    );
  }
}
