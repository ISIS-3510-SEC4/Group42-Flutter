import 'package:espoti/core/constants/input_limits.dart';
import 'package:espoti/models/meeting_record.dart';
import 'package:espoti/models/meeting_vote.dart';
import 'package:flutter_test/flutter_test.dart';

// Pruebas de la lógica pura de votación (VoteTally) y de los límites de texto.
void main() {
  const candidates = [
    MeetingCandidate(key: 'c0', name: 'Cafe A', category: 'Cafe', lat: 0, lng: 0),
    MeetingCandidate(key: 'c1', name: 'Park B', category: 'Park', lat: 0, lng: 0),
  ];

  MeetingRecord meeting({List<MeetingInvitee> invitees = const [
    MeetingInvitee(name: 'Ana', email: 'ana@example.com'),
    MeetingInvitee(name: 'Luis', email: 'luis@example.com'),
  ]}) =>
      MeetingRecord(
        id: 'm1',
        organizerId: 'org',
        activity: 'Eat',
        dayLabel: '2026-11-20',
        timeLabel: '2:00 pm',
        invitees: invitees,
        inviteeNames: invitees.map((i) => i.displayName).toList(),
        candidates: candidates,
        status: MeetingRecord.pendingVotes,
        createdAtClient: 1,
        updatedAtClient: 1,
      );

  MeetingVote vote(String uid, String email, String key, [int at = 1]) =>
      MeetingVote(
          voterUid: uid, email: email, candidateKey: key, candidateName: key, votedAt: at);

  test('meeting stays pending until every required participant votes', () {
    final tally = VoteTally.of(meeting(), [
      vote('org', '', 'c0'),
      vote('u-ana', 'ana@example.com', 'c1'),
    ]);
    expect(tally.requiredCount, 3);
    expect(tally.votedCount, 2);
    expect(tally.isComplete, isFalse);
    expect(tally.missingNames, ['Luis']);
  });

  test('a participant is counted once (latest vote wins)', () {
    final tally = VoteTally.of(meeting(), [
      vote('u-ana', 'ana@example.com', 'c0', 1),
      vote('u-ana-2', 'ana@example.com', 'c1', 2),
    ]);
    expect(tally.votedCount, 1);
    expect(tally.counts['c1'], 1);
    expect(tally.counts['c0'], 0);
  });

  test('votes from non participants or unknown places are ignored', () {
    final tally = VoteTally.of(meeting(), [
      vote('x', 'stranger@example.com', 'c0'),
      vote('u-ana', 'ana@example.com', 'c9'),
    ]);
    expect(tally.votedCount, 0);
    expect(tally.winner, isNull);
  });

  test('complete vote: most voted place wins', () {
    final tally = VoteTally.of(meeting(), [
      vote('org', '', 'c0'),
      vote('u-ana', 'ana@example.com', 'c1'),
      vote('u-luis', 'luis@example.com', 'c1'),
    ]);
    expect(tally.isComplete, isTrue);
    expect(tally.winner!.key, 'c1');
  });

  test('tie: the organizer choice wins', () {
    final tally = VoteTally.of(
        meeting(invitees: const [MeetingInvitee(name: 'Ana', email: 'ana@example.com')]),
        [vote('org', '', 'c1'), vote('u-ana', 'ana@example.com', 'c0')]);
    expect(tally.isComplete, isTrue);
    expect(tally.winner!.key, 'c1');
  });

  test('candidates survive a JSON round trip of the meeting', () {
    final restored = MeetingRecord.tryFromMap(meeting().toJson())!;
    expect(restored.candidates.map((c) => c.key), ['c0', 'c1']);
    expect(restored.isVotingOpen, isTrue);
  });

  test('participant key: organizer by uid, invitee by email', () {
    final m = meeting();
    expect(VoteTally.participantKeyFor(m, 'org', null), VoteTally.organizerKey);
    expect(VoteTally.participantKeyFor(m, 'u', 'ANA@example.com'), 'ana@example.com');
    expect(VoteTally.participantKeyFor(m, 'u', 'x@example.com'), isNull);
  });

  test('input limits report text that is too long', () {
    expect(InputLimits.tooLong('abc', 3, 'Name'), isNull);
    expect(InputLimits.tooLong('abcd', 3, 'Name'), contains('at most 3'));
  });
}
