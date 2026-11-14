import 'meeting_record.dart';

/// Lugar candidato de una reunión con votación.
///
/// El organizador elige los candidatos en el paso 2 (las recomendaciones más
/// cercanas) y se guardan dentro de la reunión, así todos los participantes
/// votan sobre la misma lista. [key] es estable ("c0", "c1"...) porque la lista
/// no cambia mientras la votación está abierta.
class MeetingCandidate {
  final String key;
  final String name;
  final String category;
  final double lat;
  final double lng;

  const MeetingCandidate({
    required this.key,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'category': category,
        'lat': lat,
        'lng': lng,
      };

  static MeetingCandidate? tryFromMap(Object? map) {
    if (map is! Map) return null;
    final key = map['key'];
    final name = map['name'];
    if (key is! String || name is! String) return null;
    return MeetingCandidate(
      key: key,
      name: name,
      category: map['category'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Voto de un participante: documento `meetings/{id}/votes/{voterUid}`.
///
/// El id del documento es el uid de quien vota, así que cada usuario tiene a
/// lo sumo un voto por reunión: votar de nuevo reemplaza el voto anterior en
/// lugar de sumar otro.
class MeetingVote {
  final String voterUid;

  /// Correo (en minúsculas) con el que se identifica a un invitado. Para el
  /// organizador puede venir vacío: a él se le identifica por su uid.
  final String email;
  final String candidateKey;
  final String candidateName;
  final int votedAt;

  const MeetingVote({
    required this.voterUid,
    required this.email,
    required this.candidateKey,
    required this.candidateName,
    required this.votedAt,
  });

  Map<String, dynamic> toJson() => {
        'voterUid': voterUid,
        'email': email.trim().toLowerCase(),
        'candidateKey': candidateKey,
        'candidateName': candidateName,
        'votedAt': votedAt,
      };

  static MeetingVote? tryFromMap(Object? map) {
    if (map is! Map) return null;
    final uid = map['voterUid'];
    final key = map['candidateKey'];
    if (uid is! String || key is! String) return null;
    return MeetingVote(
      voterUid: uid,
      email: (map['email'] as String? ?? '').trim().toLowerCase(),
      candidateKey: key,
      candidateName: map['candidateName'] as String? ?? '',
      votedAt: (map['votedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Recuento de una votación (lógica pura, sin Firebase, para poder probarla).
///
/// Participantes requeridos: el organizador (identificado por su uid) y cada
/// invitado (identificado por su correo). Reglas del recuento:
///  - Un participante cuenta como máximo una vez, aunque existan varios votos
///    suyos (se toma el más reciente).
///  - Los votos de personas que ya no están invitadas, o por candidatos que no
///    existen, se ignoran: ese participante sigue figurando como pendiente.
///  - La votación está completa cuando todos los requeridos votaron.
///  - Ganador: el candidato con más votos. Empate: gana la opción del
///    organizador si está entre las empatadas; si no, la que aparece primero
///    en la lista de candidatos. Es determinista, así que cualquier
///    participante que cierre la votación obtiene el mismo resultado.
class VoteTally {
  VoteTally._({
    required this.meeting,
    required this.voteByParticipant,
    required this.counts,
  });

  final MeetingRecord meeting;

  /// Clave del participante ("organizer" o el correo) -> su voto válido.
  final Map<String, MeetingVote> voteByParticipant;

  /// Clave del candidato -> número de votos.
  final Map<String, int> counts;

  static const String organizerKey = 'organizer';

  factory VoteTally.of(MeetingRecord meeting, Iterable<MeetingVote> votes) {
    final validKeys = {for (final c in meeting.candidates) c.key};
    final invitees = meeting.inviteeEmails.toSet();
    final byParticipant = <String, MeetingVote>{};

    for (final vote in votes) {
      if (!validKeys.contains(vote.candidateKey)) continue;
      final String participant;
      if (vote.voterUid == meeting.organizerId) {
        participant = organizerKey;
      } else if (vote.email.isNotEmpty && invitees.contains(vote.email)) {
        participant = vote.email;
      } else {
        continue; // ya no es participante requerido
      }
      final previous = byParticipant[participant];
      if (previous == null || vote.votedAt >= previous.votedAt) {
        byParticipant[participant] = vote;
      }
    }

    final counts = <String, int>{for (final c in meeting.candidates) c.key: 0};
    for (final vote in byParticipant.values) {
      counts[vote.candidateKey] = (counts[vote.candidateKey] ?? 0) + 1;
    }
    return VoteTally._(
      meeting: meeting,
      voteByParticipant: byParticipant,
      counts: counts,
    );
  }

  /// Claves de todos los participantes que deben votar.
  List<String> get requiredParticipants =>
      [organizerKey, ...meeting.inviteeEmails.toSet()];

  int get requiredCount => requiredParticipants.length;
  int get votedCount => voteByParticipant.length;
  bool get isComplete => votedCount >= requiredCount;

  bool hasVoted(String participantKey) =>
      voteByParticipant.containsKey(participantKey);

  /// Nombres de quienes todavía no votaron (para mostrarlos en la interfaz).
  List<String> get missingNames => [
        for (final key in requiredParticipants)
          if (!hasVoted(key)) _displayName(key),
      ];

  String _displayName(String key) {
    if (key == organizerKey) return 'Organizer';
    for (final i in meeting.invitees) {
      if (i.normalizedEmail == key) return i.displayName;
    }
    return key;
  }

  /// Ganador provisional (o definitivo si [isComplete]); null sin votos.
  MeetingCandidate? get winner {
    if (meeting.candidates.isEmpty || votedCount == 0) return null;
    final best = counts.values.fold<int>(0, (m, c) => c > m ? c : m);
    final tied = [
      for (final c in meeting.candidates)
        if (counts[c.key] == best) c,
    ];
    final organizerChoice = voteByParticipant[organizerKey]?.candidateKey;
    for (final c in tied) {
      if (c.key == organizerChoice) return c;
    }
    return tied.first;
  }

  /// Clave de participante del usuario actual en esta reunión.
  static String? participantKeyFor(
      MeetingRecord meeting, String uid, String? email) {
    if (meeting.organizerId == uid) return organizerKey;
    final normalized = email?.trim().toLowerCase() ?? '';
    if (normalized.isNotEmpty && meeting.inviteeEmails.contains(normalized)) {
      return normalized;
    }
    return null;
  }
}
