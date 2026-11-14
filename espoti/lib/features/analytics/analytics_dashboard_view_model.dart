import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/analytics/dashboard_aggregator.dart';

enum DashboardStatus { loading, ready, error }

/// ViewModel (MVVM) del tablero de analítica.
///
/// Pipeline completo dentro de la app, con una sola base de datos:
///  1. Las pantallas registran eventos en Firestore `analytics_events`
///     (AnalyticsService, MeetingCreationTracker; vía outbox si no hay red).
///  2. Este ViewModel escucha EN TIEMPO REAL esos eventos con `snapshots()`
///     (plataforma FLUTTER, tipos de [dashboardEventTypes]).
///  3. En cada cambio, calcula las BQ con [aggregateDashboard] en un isolate
///     (`compute`) para no bloquear la interfaz.
///  4. La vista observa este ChangeNotifier y dibuja los resultados.
/// "Refresh now" vuelve a leer del servidor bajo demanda. No hay pasos
/// manuales, scripts ni archivos descargados.
class AnalyticsDashboardViewModel extends ChangeNotifier {
  AnalyticsDashboardViewModel({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  DashboardStatus _status = DashboardStatus.loading;
  Map<String, dynamic> _planning = const {};
  Map<String, dynamic> _peaks = const {};
  int _eventCount = 0;
  DateTime? _updatedAt;
  bool _fromCache = false;
  bool _refreshing = false;
  String? _error;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  int _generation = 0;
  bool _disposed = false;

  DashboardStatus get status => _status;
  Map<String, dynamic> get planningAbandonment => _planning;
  Map<String, dynamic> get meetingPeakWindows => _peaks;
  int get eventCount => _eventCount;
  DateTime? get updatedAt => _updatedAt;

  /// Los datos vienen de la caché local de Firestore (sin conexión).
  bool get fromCache => _fromCache;
  bool get refreshing => _refreshing;
  String? get error => _error;

  Query<Map<String, dynamic>> get _query =>
      (_firestore ?? FirebaseFirestore.instance)
          .collection('analytics_events')
          .where('platform', isEqualTo: 'FLUTTER')
          .where('eventType', whereIn: dashboardEventTypes);

  /// Empieza a escuchar en tiempo real. Seguro de llamar varias veces.
  void start() {
    _subscription ??= _query
        .snapshots(includeMetadataChanges: true)
        .listen(_onSnapshot, onError: _onError);
  }

  /// Lectura bajo demanda desde el servidor (botón "Refresh now").
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    _notify();
    try {
      final snap = await _query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      await _onSnapshot(snap);
    } catch (e) {
      _onError(e);
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) async {
    // Mapas planos (Timestamp -> ms) para poder enviarlos al isolate.
    final events = [for (final d in snap.docs) _plain(d.data())];
    final generation = ++_generation;
    final result = await compute(aggregateDashboard, events);
    // Si llegó otro snapshot mientras se calculaba, gana el más reciente.
    if (_disposed || generation != _generation) return;
    _planning = Map<String, dynamic>.from(result['planningAbandonment'] as Map);
    _peaks = Map<String, dynamic>.from(result['meetingPeakWindows'] as Map);
    _eventCount = result['eventCount'] as int;
    _fromCache = snap.metadata.isFromCache;
    _updatedAt = DateTime.now();
    _error = null;
    _status = DashboardStatus.ready;
    _notify();
  }

  void _onError(Object error) {
    debugPrint('AnalyticsDashboardViewModel: $error');
    _error = error is FirebaseException && error.code == 'permission-denied'
        ? 'No permission to read analytics_events. Publish the Firestore rules that allow signed-in users to list FLUTTER events.'
        : 'The analytics data could not be loaded. Check your connection.';
    if (_status == DashboardStatus.loading) _status = DashboardStatus.error;
    _notify();
  }

  /// Reintento completo tras un error.
  void retry() {
    _subscription?.cancel();
    _subscription = null;
    _status = DashboardStatus.loading;
    _error = null;
    _notify();
    start();
  }

  static Map<String, dynamic> _plain(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(k, _plainValue(v)));

  static Object? _plainValue(Object? v) {
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is Map) {
      return v.map((k, value) => MapEntry(k.toString(), _plainValue(value)));
    }
    if (v is List) return v.map(_plainValue).toList();
    if (v is GeoPoint || v is DocumentReference) return v.toString();
    return v;
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
