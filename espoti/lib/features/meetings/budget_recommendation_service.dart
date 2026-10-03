import '../../models/meeting.dart';

class BudgetRecommendationResult {
  final List<Meeting> places;

  /// Compatible budget per person (COP) used, or null if nobody set one.
  final int? budget;

  /// True when no place fit the budget and the cheapest ones are shown.
  final bool relaxed;

  const BudgetRecommendationResult(this.places, this.budget,
      {this.relaxed = false});
}

/// Budget-based filtering on top of the places returned by
/// `NearbyRecommendationsService` (which is not modified).
///
/// OpenStreetMap has no prices, so cost per person is an estimate based on the
/// place category label the nearby service already provides.
class BudgetRecommendationService {
  BudgetRecommendationService._();

  /// Estimated cost per person in COP by category.
  static const Map<String, int> _estimatedCostByCategory = {
    'Cafetería': 15000,
    'Comida rápida': 20000,
    'Bar': 40000,
    'Restaurante': 45000,
  };

  /// Compatible budget = the highest amount EVERY participant can afford,
  /// i.e. the lowest maximum budget declared. Null if none was declared.
  static int? compatibleBudget(Iterable<int?> maxBudgets) {
    final valid = maxBudgets.whereType<int>().where((b) => b > 0).toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a < b ? a : b);
  }

  static int? estimateCost(Meeting place) =>
      _estimatedCostByCategory[place.timeLabel];

  /// Keeps affordable places first (original distance order preserved), then
  /// places with unknown price. Unaffordable places are dropped, unless none
  /// fit, in which case the cheapest are shown with [relaxed] = true.
  static BudgetRecommendationResult apply(List<Meeting> places, int? budget) {
    if (budget == null) return BudgetRecommendationResult(places, null);

    final priced = [
      for (final p in places)
        (place: p, cost: estimateCost(p)),
    ];
    final affordable = [
      for (final e in priced)
        if (e.cost != null && e.cost! <= budget)
          e.place.withEstimatedCost(e.cost!)
    ];
    final unknown = [
      for (final e in priced)
        if (e.cost == null) e.place
    ];

    if (affordable.isNotEmpty || unknown.isNotEmpty) {
      return BudgetRecommendationResult([...affordable, ...unknown], budget);
    }

    final cheapest = [...priced]..sort((a, b) => a.cost!.compareTo(b.cost!));
    return BudgetRecommendationResult(
      [for (final e in cheapest) e.place.withEstimatedCost(e.cost!)],
      budget,
      relaxed: true,
    );
  }

  /// Formats 45000 as "45.000".
  static String formatCop(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
