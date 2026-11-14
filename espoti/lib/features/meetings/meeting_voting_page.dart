import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/offline/connectivity_service.dart';
import '../../core/services/meeting_voting_service.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../models/meeting_record.dart';
import '../../models/meeting_vote.dart';

/// Votación de una reunión (invitados y organizador).
/// Abrir con `arguments: {'meetingId': id}`.
///
/// Muestra los lugares candidatos, el voto actual del usuario, cuántos
/// votaron y quiénes faltan. Mientras la votación está abierta se puede votar
/// o cambiar el voto (sigue siendo un solo voto por persona). Cuando votaron
/// todos, la pantalla muestra el lugar ganador.
class MeetingVotingPage extends StatefulWidget {
  const MeetingVotingPage({super.key});

  @override
  State<MeetingVotingPage> createState() => _MeetingVotingPageState();
}

class _MeetingVotingPageState extends State<MeetingVotingPage> {
  String? _meetingId;
  VoteItem? _item;
  MeetingRecord? _meeting;
  String? _selectedKey;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  bool _didReadArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;
    _didReadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    _meetingId = args is Map ? args['meetingId'] as String? : null;
    _load();
  }

  /// Carga la reunión (memoria, copia local o Firestore) y su recuento.
  Future<void> _load() async {
    final id = _meetingId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Meeting not found.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = MeetingVotingService.instance;
    final meeting = service.itemFor(id)?.meeting ?? await service.fetchMeeting(id);
    if (meeting == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This meeting is not available. Check your connection.';
      });
      return;
    }
    final item = await service.evaluateOne(meeting);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _meeting = item?.meeting ?? meeting;
      _item = item;
      _selectedKey ??= item?.myVote?.candidateKey;
      if (item == null) _error = 'You are not a participant of this meeting.';
    });
  }

  Future<void> _submit() async {
    final item = _item;
    final key = _selectedKey;
    if (item == null || key == null || _submitting) return;
    final candidate = item.meeting.candidates.firstWhere((c) => c.key == key);
    setState(() => _submitting = true);
    try {
      final online = await ConnectivityService.instance.check();
      final updated =
          await MeetingVotingService.instance.submitVote(item.meeting, candidate);
      if (!mounted) return;
      setState(() {
        if (updated != null) {
          _item = updated;
          _meeting = updated.meeting;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(online
            ? 'Your vote for ${candidate.name} was saved.'
            : 'You are offline: your vote is saved on this phone and will be sent when you reconnect.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is StateError ? e.message : 'Could not save your vote.'),
        backgroundColor: Colors.red.shade700,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                title: 'Vote',
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primaryBrown),
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final meeting = _meeting;
    final item = _item;
    if (meeting == null || item == null) {
      return _Message(text: _error ?? 'Meeting not found.', onRetry: _load);
    }
    final tally = item.tally;
    final open = meeting.isVotingOpen;
    final winner = open ? null : tally.winner;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        children: [
          Text(meeting.title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
          Text(meeting.whenLabel,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppDimensions.paddingM),
          _StatusCard(item: item),
          const SizedBox(height: AppDimensions.paddingM),
          if (!open && meeting.placeName != null) ...[
            const Text('Winning place',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined, color: AppColors.orange),
              title: Text(meeting.placeName!),
              subtitle: Text(meeting.placeCategory ?? ''),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.meetingDetail,
                  arguments: {'meetingId': meeting.id}),
              child: const Text('Open meeting details'),
            ),
          ] else if (meeting.candidates.isEmpty)
            const _Message(text: 'This meeting has no places to vote for.')
          else ...[
            Text(open ? 'Choose a place:' : 'Places',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
            // Selección única con ListTile + ícono de radio (RadioListTile
            // con groupValue/onChanged está deprecado desde Flutter 3.32).
            for (final c in meeting.candidates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: open && !_submitting,
                selected: _selectedKey == c.key,
                selectedColor: AppColors.primaryBrown,
                leading: Icon(_selectedKey == c.key
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                onTap: () => setState(() => _selectedKey = c.key),
                title: Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${c.category}${c.category.isEmpty ? '' : ' · '}'
                  '${tally.counts[c.key] ?? 0} vote(s)'
                  '${winner?.key == c.key ? ' · winner' : ''}',
                ),
              ),
            if (open) ...[
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: _selectedKey == null || _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrown,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white))
                    : Text(item.myVote == null ? 'Submit vote' : 'Change my vote'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Estado de la votación: votos emitidos, quién falta y el voto propio.
class _StatusCard extends StatelessWidget {
  final VoteItem item;
  const _StatusCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final VoteTally t = item.tally;
    final open = item.meeting.isVotingOpen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: open ? AppColors.accent1 : AppColors.orange50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(open ? 'Voting in progress' : 'Voting closed',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          Text('${t.votedCount} of ${t.requiredCount} participants have voted.',
              style: const TextStyle(color: AppColors.text)),
          if (open && t.missingNames.isNotEmpty)
            Text('Waiting for: ${t.missingNames.join(', ')}',
                style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            item.myVote == null
                ? (open ? 'You have not voted yet.' : 'You did not vote.')
                : 'Your vote: ${item.myVote!.candidateName}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (item.votesUnavailable)
            const Text(
              'Offline: the vote count may be incomplete. It refreshes when you reconnect.',
              style: TextStyle(fontSize: 12, color: AppColors.orange),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Future<void> Function()? onRetry;
  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
