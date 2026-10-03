import 'package:espoti/core/analytics/analytics_event_factory.dart';
import 'package:espoti/core/analytics/analytics_repository.dart';
import 'package:espoti/core/analytics/analytics_tracker.dart';
import 'package:espoti/models/analytics_event.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements AnalyticsRepository {
  final saved = <AnalyticsEvent>[];

  @override
  Future<void> saveEvent(AnalyticsEvent event) async => saved.add(event);
}

void main() {
  late _FakeRepository repository;
  late RecommendationReviewTracker tracker;
  var nextId = 0;

  setUp(() {
    repository = _FakeRepository();
    tracker = RecommendationReviewTracker(
      repository: repository,
      factory: AnalyticsEventFactory(
        sessionId: 'session',
        idGenerator: () => 'id-${nextId++}',
      ),
      currentUserId: () => 'user-1',
    );
  });

  test('counts each viewed place once and reports it on selection', () {
    tracker.displayed(resultCount: 3);
    tracker.viewed('A');
    tracker.viewed('A');
    tracker.viewed('B');
    tracker.selected('B');

    final selected = repository.saved.last;
    expect(selected.eventType, AnalyticsEventType.recommendationSelected);
    expect(selected.metadata['viewedCount'], 2);
    expect(selected.platform, 'FLUTTER');
  });

  test('selected place counts as viewed even if never opened', () {
    tracker.displayed(resultCount: 2);
    tracker.selected('A');

    expect(repository.saved.last.metadata['viewedCount'], 1);
  });

  test('new list resets the count and request id', () {
    tracker.displayed(resultCount: 2);
    tracker.viewed('A');
    final firstRequest = repository.saved.first.metadata['requestId'];

    tracker.displayed(resultCount: 2);
    tracker.selected('B');

    final selected = repository.saved.last;
    expect(selected.metadata['viewedCount'], 1);
    expect(selected.metadata['requestId'], isNot(firstRequest));
  });

  test('stores nothing without a signed-in user', () {
    final anonymous = RecommendationReviewTracker(
      repository: repository,
      factory: AnalyticsEventFactory(sessionId: 'session'),
      currentUserId: () => null,
    );
    anonymous.displayed(resultCount: 2);
    anonymous.selected('A');

    expect(repository.saved, isEmpty);
  });
}
