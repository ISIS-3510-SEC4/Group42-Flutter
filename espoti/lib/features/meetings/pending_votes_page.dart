import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/meeting_voting_service.dart';
import '../../core/widgets/espoti_top_bar.dart';

/// Lista de votaciones del usuario (pantalla completa, desde el menú).
class PendingVotesPage extends StatefulWidget {
  const PendingVotesPage({super.key});

  @override
  State<PendingVotesPage> createState() => _PendingVotesPageState();
}

class _PendingVotesPageState extends State<PendingVotesPage> {
  @override
  void initState() {
    super.initState();
    MeetingVotingService.instance.refresh();
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
                  AppDimensions.paddingM, AppDimensions.paddingL, 0),
              child: EspotiTopBar(
                title: 'Pending votes',
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primaryBrown),
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: MeetingVotingService.instance.refresh,
                child: ListView(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  children: const [PendingVotesSection(showEmptyState: true)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sección reutilizable (Home y pantalla de votaciones).
///
/// Sin notificaciones: cuando el usuario entra a la app, Home llama a
/// [MeetingVotingService.refresh] y esta sección muestra claramente las
/// reuniones que esperan su voto, con un botón para votar, y las votaciones
/// en las que ya votó y faltan otros.
class PendingVotesSection extends StatelessWidget {
  /// En Home la sección se oculta si no hay nada; en la pantalla dedicada se
  /// muestra un estado vacío.
  final bool showEmptyState;

  const PendingVotesSection({super.key, this.showEmptyState = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VotingOverview>(
      valueListenable: MeetingVotingService.instance.overview,
      builder: (context, overview, _) {
        final needMyVote = overview.openVotes.where((v) => v.needsMyVote).toList();
        final waiting = overview.openVotes.where((v) => !v.needsMyVote).toList();
        // Las reuniones a las que fue invitado ya no se listan aquí: aparecen
        // en Next Meetings / Meeting History y en las pestañas de Meetings.
        final nothing = needMyVote.isEmpty && waiting.isEmpty;

        final children = <Widget>[
          if (overview.loading && nothing)
            const LinearProgressIndicator(),
          if (overview.error != null) _note(overview.error!),
          if (overview.offline)
            _note('Offline: showing the invitations saved on this phone.'),
          if (overview.emailNotVerified) const _VerifyEmailNote(),
          if (needMyVote.isNotEmpty) ...[
            _VoteBanner(count: needMyVote.length),
            for (final item in needMyVote)
              _VoteTile(item: item, actionLabel: 'Vote'),
          ],
          if (waiting.isNotEmpty) ...[
            const _Subtitle('Waiting for other participants'),
            for (final item in waiting)
              _VoteTile(item: item, actionLabel: 'View'),
          ],
          if (nothing && !overview.loading && showEmptyState)
            _note('You have no pending votes.'),
        ];
        if (children.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  static Widget _note(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
}

class _Subtitle extends StatelessWidget {
  final String text;
  const _Subtitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppDimensions.paddingM),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
      );
}

/// Aviso destacado: hay reuniones esperando el voto del usuario.
class _VoteBanner extends StatelessWidget {
  final int count;
  const _VoteBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          const Icon(Icons.how_to_vote, color: AppColors.primaryBrown),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              count == 1
                  ? 'You have 1 meeting waiting for your vote.'
                  : 'You have $count meetings waiting for your vote.',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteTile extends StatelessWidget {
  final VoteItem item;
  final String actionLabel;
  const _VoteTile({required this.item, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final t = item.tally;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(item.isOrganizer ? Icons.star_outline : Icons.mail_outline,
          color: AppColors.primaryBrown),
      title: Text(item.meeting.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.meeting.whenLabel} · ${t.votedCount}/${t.requiredCount} voted'
        '${item.isOrganizer ? ' · you organize it' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: TextButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.meetingVoting,
            arguments: {'meetingId': item.meeting.id}),
        child: Text(actionLabel),
      ),
    );
  }
}

/// Las invitaciones se reconocen por correo verificado (reglas de
/// Firestore). Si el correo no está verificado se explica y se ofrece enviar
/// el correo de verificación de Firebase Auth (no es una notificación de la
/// app).
class _VerifyEmailNote extends StatefulWidget {
  const _VerifyEmailNote();

  @override
  State<_VerifyEmailNote> createState() => _VerifyEmailNoteState();
}

class _VerifyEmailNoteState extends State<_VerifyEmailNote> {
  bool _sent = false;

  Future<void> _send() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send the verification email. Try again later.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invitations are matched by verified email. Verify your email to see meetings you were invited to.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: _sent ? null : _send,
            child: Text(_sent
                ? 'Verification email sent. Log in again after verifying.'
                : 'Send verification email'),
          ),
        ],
      ),
    );
  }
}
