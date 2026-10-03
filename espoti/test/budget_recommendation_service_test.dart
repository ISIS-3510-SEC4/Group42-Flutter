import 'package:flutter_test/flutter_test.dart';
import 'package:espoti/features/meetings/budget_recommendation_service.dart';
import 'package:espoti/models/meeting.dart';

Meeting _place(String name, String category) =>
    Meeting(placeName: name, timeLabel: category, distanceLabel: '100 m');

void main() {
  test('compatible budget is the lowest declared maximum', () {
    expect(BudgetRecommendationService.compatibleBudget([50000, null, 30000]),
        30000);
    expect(BudgetRecommendationService.compatibleBudget([null, null]), isNull);
  });

  test('filters out places above the budget', () {
    final result = BudgetRecommendationService.apply([
      _place('A', 'Restaurante'),
      _place('B', 'Cafetería'),
    ], 20000);
    expect(result.places.map((p) => p.placeName), ['B']);
    expect(result.relaxed, isFalse);
  });

  test('shows cheapest places when none fit', () {
    final result = BudgetRecommendationService.apply([
      _place('A', 'Restaurante'),
      _place('B', 'Bar'),
    ], 5000);
    expect(result.relaxed, isTrue);
    expect(result.places.first.placeName, 'B');
  });

  test('no budget leaves recommendations untouched', () {
    final places = [_place('A', 'Restaurante')];
    expect(BudgetRecommendationService.apply(places, null).places, places);
  });

  test('formats COP amounts', () {
    expect(BudgetRecommendationService.formatCop(45000), '45.000');
  });
}
