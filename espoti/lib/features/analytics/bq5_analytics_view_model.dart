import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/analytics/dashboard_aggregator.dart';

enum Bq5AnalyticsStatus { loading, ready, error }

class Bq5AnalyticsViewModel extends ChangeNotifier {
  Bq5AnalyticsViewModel({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Bq5AnalyticsStatus _status = Bq5AnalyticsStatus.loading;
  Map<String, dynamic> _data = const {};
  bool _hasData = false;
  bool _fromCache = false;
  bool _refreshing = false;
  String? _error;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  int _generation = 0;
  bool _disposed = false;

  Bq5AnalyticsStatus get status => _status;
  Map<String, dynamic> get data => _data;
  bool get hasData => _hasData;
  bool get fromCache => _fromCache;
  bool get refreshing => _refreshing;
  String? get error => _error;

  Query<Map<String, dynamic>> get _query =>
      (_firestore ?? FirebaseFirestore.instance)
          .collection('analytics_events')
          .where('platform', isEqualTo: 'FLUTTER');

  void start() {
    _subscription ??= _query
        .snapshots(includeMetadataChanges: true)
        .listen(_onSnapshot, onError: _onError);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _notify();
    try {
      final snapshot = await _query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      await _onSnapshot(snapshot);
    } catch (error) {
      _onError(error);
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> _onSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final events = snapshot.docs
        .where(
      (document) => document.data()['eventType'] == 'RECOMMENDATION_DECISION',
    )
        .map((document) {
      final data = document.data();
      final metadata = data['metadata'];
      return <String, dynamic>{
        'eventType': data['eventType'],
        'metadata': metadata is Map
            ? Map<String, dynamic>.from(metadata)
            : <String, dynamic>{},
      };
    }).toList(growable: false);

    final generation = ++_generation;
    final result = await compute(aggregateRecommendationAcceptance, events);
    if (_disposed || generation != _generation) return;

    _data = {
      ...result,
      'calculatedAt': Timestamp.now(),
      'fromCache': snapshot.metadata.isFromCache,
    };
    _hasData = true;
    _fromCache = snapshot.metadata.isFromCache;
    _error = null;
    _status = Bq5AnalyticsStatus.ready;
    _notify();
  }

  void _onError(Object error) {
    debugPrint('Bq5AnalyticsViewModel: $error');
    _error = error is FirebaseException && error.code == 'permission-denied'
        ? 'You do not have permission to read Flutter analytics.'
        : 'Analytics could not be loaded. Check your connection.';
    if (!_hasData) _status = Bq5AnalyticsStatus.error;
    _notify();
  }

  void retry() {
    _subscription?.cancel();
    _subscription = null;
    _status = Bq5AnalyticsStatus.loading;
    _error = null;
    _notify();
    start();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
