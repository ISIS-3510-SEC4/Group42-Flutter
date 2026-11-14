import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/meeting_record.dart';
import '../../models/meeting_vote.dart';
import '../offline/connectivity_service.dart';
import '../offline/local_store.dart';
import '../offline/pending_operation.dart';
import '../offline/sync_service.dart';
import 'meeting_repository.dart';

/// Una reunión con votación vista por el usuario actual.
@immutable
class VoteItem {
  final MeetingRecord meeting;
  final VoteTally tally;

  /// El usuario es el organizador (si no, es invitado).
  final bool isOrganizer;

  /// Clave de participante del usuario ("organizer" o su correo).
  final String participantKey;

  /// Los votos no se pudieron leer del servidor (sin conexión): el recuento
  /// puede estar incompleto.
  final bool votesUnavailable;

  const VoteItem({
    required this.meeting,
    required this.tally,
    required this.isOrganizer,
    required this.participantKey,
    this.votesUnavailable = false,
  });

  MeetingVote? get myVote => tally.voteByParticipant[participantKey];

  /// Falta el voto de este usuario y la votación sigue abierta.
  bool get needsMyVote => meeting.isVotingOpen && myVote == null;
}

/// Estado que observa la interfaz (Home, pantalla de votación).
@immutable
class VotingOverview {
  final bool loading;

  /// Reuniones con votación abierta en las que participa el usuario.
  final List<VoteItem> openVotes;

  /// Todas las reuniones a las que fue invitado (cualquier estado). Las usa
  /// MeetingsViewModel para mostrarlas en Upcoming / Previous / Canceled
  /// junto a las reuniones propias.
  final List<MeetingRecord> invited;

  /// El correo no está verificado: las invitaciones se reconocen por correo
  /// verificado (ver firestore.rules), así que no se pueden consultar.
  final bool emailNotVerified;

  /// Las invitaciones se mostraron desde la copia local (sin conexión).
  final bool offline;
  final String? error;

  const VotingOverview({
    this.loading = false,
    this.openVotes = const [],
    this.invited = const [],
    this.emailNotVerified = false,
    this.offline = false,
    this.error,
  });

  int get pendingMyVote => openVotes.where((v) => v.needsMyVote).length;
}

/// Flujo de votación de reuniones con invitados.
///
/// Datos:
///  - La reunión guarda `candidates` y `status`.
///  - Cada voto es `meetings/{id}/votes/{uid}` (un documento por usuario, así
///    nunca hay dos votos de la misma persona).
///
/// Transiciones de estado:
///  planning --(el organizador vota y hay invitados)--> pending_votes
///  pending_votes --(votaron todos los requeridos)--> scheduled (+ lugar)
///  planning --(el organizador vota y no hay invitados)--> scheduled
///
/// El cierre lo hace el primer cliente que ve la votación completa: el
/// organizador lo guarda por el outbox (funciona sin conexión) y un invitado
/// lo actualiza directamente en Firestore (las reglas solo le permiten tocar
/// el estado y el lugar). Como el recuento es determinista ([VoteTally]),
/// todos llegan al mismo ganador. Sin notificaciones: al entrar a la app
/// (Home) se llama [refresh] y se muestran las votaciones pendientes.
class MeetingVotingService {
  MeetingVotingService._();
  static final MeetingVotingService instance = MeetingVotingService._();

  static const Duration _timeout = Duration(seconds: 10);

  final ValueNotifier<VotingOverview> overview =
      ValueNotifier(const VotingOverview());

  /// Reuniones de las que el usuario es invitado (para abrir su detalle).
  final Map<String, MeetingRecord> _invited = {};

  /// Votos propios guardados en el outbox que quizá aún no llegaron al
  /// servidor; se suman al recuento para que la interfaz no los "pierda".
  final Map<String, MeetingVote> _localVotes = {};

  Future<void>? _refreshing;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;

  // Caché local de invitaciones por usuario (LocalStore): se muestran sin
  // conexión.
  static String _cacheKey(String uid) => 'espoti_invited_meetings_v1_$uid';

  MeetingRecord? cachedInvited(String meetingId) => _invited[meetingId];

  VoteItem? itemFor(String meetingId) {
    for (final item in overview.value.openVotes) {
      if (item.meeting.id == meetingId) return item;
    }
    return null;
  }

  /// Al cerrar sesión: olvidar datos del usuario anterior.
  void clear() {
    _invited.clear();
    _localVotes.clear();
    overview.value = const VotingOverview();
  }

  /// Recalcula todas las votaciones del usuario y cierra las que ya estén
  /// completas. Si ya hay una actualización en curso, se reutiliza.
  Future<void> refresh() => _refreshing ??=
      _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final user = _user;
    if (user == null) {
      clear();
      return;
    }
    overview.value = VotingOverview(
      loading: true,
      openVotes: overview.value.openVotes,
      invited: overview.value.invited,
    );

    try {
      final online = await ConnectivityService.instance.check();

      // 1) Reuniones propias con votación abierta (copia local + servidor).
      final hasLocalOpen = (await MeetingRepository.instance.myMeetings())
          .meetings
          .any((m) => m.isVotingOpen);
      final mine = (await MeetingRepository.instance
              .myMeetings(forceRefresh: online && hasLocalOpen))
          .meetings
          .where((m) => m.isVotingOpen)
          .toList();

      // 2) Reuniones donde el usuario está invitado (por correo verificado).
      final email = user.email?.trim().toLowerCase() ?? '';
      final verified = user.emailVerified && email.isNotEmpty;
      var invited = <MeetingRecord>[];
      var fromCache = false;
      if (verified) {
        try {
          if (!online) throw const _OfflineError();
          invited = await _fetchInvited(email);
          unawaited(_saveInvitedCache(user.uid, invited));
        } catch (e) {
          if (e is! _OfflineError) debugPrint('Invited meetings not loaded: $e');
          invited = await _readInvitedCache(user.uid);
          fromCache = true;
        }
      }
      _invited
        ..clear()
        ..addEntries(invited.map((m) => MapEntry(m.id, m)));

      // 3) Recuento de cada votación abierta y cierre si está completa.
      final open = <VoteItem>[];
      for (final meeting in [...mine, ...invited.where((m) => m.isVotingOpen)]) {
        final item = await _evaluate(meeting, user, online: online);
        if (item == null) continue;
        if (item.meeting.isVotingOpen) open.add(item);
      }

      // _invited ya incluye las que se acaban de cerrar (lugar ganador).
      overview.value = VotingOverview(
        openVotes: open,
        invited: _invited.values.toList(),
        emailNotVerified: !verified,
        offline: fromCache,
      );
    } catch (e) {
      debugPrint('Voting refresh failed: $e');
      overview.value = VotingOverview(
        openVotes: overview.value.openVotes,
        invited: overview.value.invited,
        error: 'Could not load your pending votes.',
      );
    }
  }

  /// Lee los votos de [meeting], arma el recuento y la cierra si corresponde.
  Future<VoteItem?> _evaluate(MeetingRecord meeting, User user,
      {required bool online}) async {
    final key = VoteTally.participantKeyFor(meeting, user.uid, user.email);
    if (key == null) return null;

    var votes = <MeetingVote>[];
    var unavailable = false;
    if (online) {
      try {
        votes = await _fetchVotes(meeting.id);
      } catch (e) {
        debugPrint('Votes of ${meeting.id} not loaded: $e');
        unavailable = true;
      }
    } else {
      unavailable = true;
    }
    final local = _localVotes[meeting.id];
    if (local != null && !votes.any((v) => v.voterUid == local.voterUid && v.votedAt >= local.votedAt)) {
      votes = [...votes.where((v) => v.voterUid != local.voterUid), local];
    }

    var current = meeting;
    final tally = VoteTally.of(meeting, votes);
    // Solo se cierra con los votos del servidor: con datos incompletos
    // (sin conexión) nunca se decide un ganador.
    if (meeting.isVotingOpen && tally.isComplete && !unavailable) {
      current = await _close(meeting, tally, user) ?? meeting;
    }
    return VoteItem(
      meeting: current,
      tally: VoteTally.of(current, votes),
      isOrganizer: meeting.organizerId == user.uid,
      participantKey: key,
      votesUnavailable: unavailable,
    );
  }

  /// Registra o cambia el voto del usuario. Se guarda primero en el outbox
  /// (funciona sin conexión) y luego se intenta cerrar la votación.
  Future<VoteItem?> submitVote(
      MeetingRecord meeting, MeetingCandidate candidate) async {
    final user = _user;
    if (user == null) throw StateError('Sign in to vote.');
    final key = VoteTally.participantKeyFor(meeting, user.uid, user.email);
    if (key == null) {
      throw StateError('You are not a participant of this meeting.');
    }
    if (!meeting.isVotingOpen) {
      throw StateError('Voting for this meeting is already closed.');
    }
    if (!meeting.candidates.any((c) => c.key == candidate.key)) {
      throw StateError('This place is not one of the options.');
    }

    final vote = MeetingVote(
      voterUid: user.uid,
      email: user.email ?? '',
      candidateKey: candidate.key,
      candidateName: candidate.name,
      votedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _localVotes[meeting.id] = vote;
    await SyncService.instance.enqueue(PendingOperation.create(
      kind: PendingWriteKind.upsert,
      collection: '${MeetingRepository.collection}/${meeting.id}/votes',
      docId: user.uid,
      ownerUid: user.uid,
      data: vote.toJson(),
    ));
    // Esperar el envío para que el recuento del servidor ya incluya este voto.
    await SyncService.instance.syncNow().timeout(_timeout, onTimeout: () {});

    final online = await ConnectivityService.instance.check();
    final item = await _evaluate(meeting, user, online: online);
    unawaited(refresh());
    return item;
  }

  /// Cierra la votación: estado scheduled y lugar ganador.
  Future<MeetingRecord?> _close(
      MeetingRecord meeting, VoteTally tally, User user) async {
    final winner = tally.winner;
    if (winner == null) return null;
    final closed = meeting.copyWith(
      status: MeetingRecord.scheduled,
      placeName: winner.name,
      placeCategory: winner.category,
    );
    try {
      if (meeting.organizerId == user.uid) {
        // Organizador: por el outbox, como cualquier edición de la reunión.
        return await MeetingRepository.instance.save(closed);
      }
      // Invitado: actualización directa y acotada (ver firestore.rules).
      await _db.collection(MeetingRepository.collection).doc(meeting.id).update({
        'status': MeetingRecord.scheduled,
        'placeName': winner.name,
        'placeCategory': winner.category,
        'votingClosedAt': FieldValue.serverTimestamp(),
        'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
      _invited[meeting.id] = closed;
      return closed;
    } catch (e) {
      // Si falla (sin red, la cerró otra persona...), sigue abierta en este
      // dispositivo y se reintenta en el próximo refresh.
      debugPrint('Voting of ${meeting.id} not closed: $e');
      return null;
    }
  }

  // Invitaciones: las reuniones donde el usuario está invitado se encuentran
  // por correo (inviteeEmails array-contains). Requiere correo verificado (la
  // regla isInvited usa email_verified). No se envía correo ni notificación: el
  // invitado las ve al entrar a la app con ese mismo correo.
  Future<List<MeetingRecord>> _fetchInvited(String email) async {
    final query = await _db
        .collection(MeetingRepository.collection)
        .where('inviteeEmails', arrayContains: email)
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    return [
      for (final doc in query.docs)
        if (MeetingRecord.tryFromMap(_plain({...doc.data(), 'id': doc.id}))
            case final record?)
          record,
    ];
  }

  Future<List<MeetingVote>> _fetchVotes(String meetingId) async {
    final query = await _db
        .collection(MeetingRepository.collection)
        .doc(meetingId)
        .collection('votes')
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    return query.docs
        .map((d) => MeetingVote.tryFromMap(d.data()))
        .whereType<MeetingVote>()
        .toList();
  }

  /// Lee una reunión directamente (por ejemplo, si se abre desde un enlace
  /// interno y aún no está en memoria).
  Future<MeetingRecord?> fetchMeeting(String meetingId) async {
    final cached = _invited[meetingId] ??
        await MeetingRepository.instance.byId(meetingId);
    if (cached != null) return cached;
    try {
      final doc = await _db
          .collection(MeetingRepository.collection)
          .doc(meetingId)
          .get()
          .timeout(_timeout);
      final data = doc.data();
      if (data == null) return null;
      return MeetingRecord.tryFromMap(_plain({...data, 'id': doc.id}));
    } catch (e) {
      debugPrint('Meeting $meetingId not loaded: $e');
      return null;
    }
  }

  /// Recalcula la votación de una sola reunión (pantalla de votación).
  Future<VoteItem?> evaluateOne(MeetingRecord meeting) async {
    final user = _user;
    if (user == null) return null;
    final online = await ConnectivityService.instance.check();
    return _evaluate(meeting, user, online: online);
  }

  // Timestamps de Firestore -> epoch millis, el formato de MeetingRecord.
  static Map<String, dynamic> _plain(Map<String, dynamic> data) => data.map(
      (k, v) => MapEntry(k, v is Timestamp ? v.millisecondsSinceEpoch : v));

  Future<void> _saveInvitedCache(String uid, List<MeetingRecord> meetings) =>
      LocalStore.instance
          .writeJson(_cacheKey(uid), meetings.map((m) => m.toJson()).toList())
          .catchError((Object e) => debugPrint('Invited cache not saved: $e'));

  Future<List<MeetingRecord>> _readInvitedCache(String uid) async {
    final raw = await LocalStore.instance.readJson(_cacheKey(uid));
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          if (MeetingRecord.tryFromMap(Map<String, dynamic>.from(item))
              case final record?)
            record,
    ];
  }
}

class _OfflineError implements Exception {
  const _OfflineError();
}
