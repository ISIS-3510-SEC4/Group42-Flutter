import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum AnalyticsResultStatus { loading, empty, error, ready }

// ViewModel compartido por los dashboards de VV2 (abandono) y VV3 (BQ tipo 4).
// La app no calcula métricas: solo lee el documento agregado que escriben los
// scripts de analytics/ con credenciales de administrador.
/// ViewModel (MVVM) for a dashboard backed by one precomputed aggregate in
/// Firestore `analytics_results/{docId}`. The aggregates are produced by the
/// scripts in `analytics/` (they need admin credentials, so they never run
/// inside the app). The screen observes this ChangeNotifier and only renders
/// [status] / [data]; it never talks to Firestore itself.
class AnalyticsResultViewModel extends ChangeNotifier {
  AnalyticsResultViewModel({required this.docId, FirebaseFirestore? firestore})
      : _firestore = firestore;

  final String docId;
  final FirebaseFirestore? _firestore;

  AnalyticsResultStatus _status = AnalyticsResultStatus.loading;
  Map<String, dynamic>? _data;
  String? _error;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  bool _disposed = false;

  AnalyticsResultStatus get status => _status;

  /// Aggregate as written by the script (only when [status] is ready).
  Map<String, dynamic>? get data => _data;

  /// Readable error (only when [status] is error).
  String? get error => _error;

  // Observer con Stream: snapshots() emite cada vez que cambia
  // analytics_results/{docId}; al volver a ejecutar el script la pantalla se
  // actualiza sola. La suscripción se cancela en dispose() y en retry().
  /// Starts listening to the aggregate. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    final db = _firestore ?? FirebaseFirestore.instance;
    _subscription = db
        .collection('analytics_results')
        .doc(docId)
        .snapshots()
        .listen(_onSnapshot, onError: _onError);
  }

  /// Retries after an error.
  void retry() {
    _subscription?.cancel();
    _subscription = null;
    _set(AnalyticsResultStatus.loading);
    start();
  }

  // Si el documento no existe → estado empty (nunca se muestran datos de
  // ejemplo).
  void _onSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (!doc.exists || data == null) {
      _data = null;
      _set(AnalyticsResultStatus.empty);
      return;
    }
    _data = data;
    _set(AnalyticsResultStatus.ready);
  }

  // permission-denied suele indicar que las reglas de firestore.rules no están
  // desplegadas; cualquier otro error se muestra como problema de conexión.
  void _onError(Object error) {
    _data = null;
    _error = error is FirebaseException && error.code == 'permission-denied'
        ? 'No permission to read analytics_results/$docId. Check that the '
            'firestore.rules rules are deployed.'
        : 'The result could not be loaded. Check your connection.';
    debugPrint('AnalyticsResultViewModel($docId): $error');
    _set(AnalyticsResultStatus.error);
  }

  void _set(AnalyticsResultStatus status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers to read the aggregate safely (values come from Firestore).

  static int intOf(Object? value) => value is num ? value.toInt() : 0;

  static double doubleOf(Object? value) =>
      value is num ? value.toDouble() : 0.0;

  static Map<String, dynamic> mapOf(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static String? updatedAtLabel(Map<String, dynamic> data) {
    final value = data['updatedAt'];
    if (value is! Timestamp) return null;
    return value.toDate().toLocal().toString().split('.').first;
  }
}
