import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'connectivity_service.dart';
import 'local_store.dart';
import 'pending_operation.dart';

// Estado actual de la sincronización, utilizado para mostrar indicadores en la interfaz.
@immutable
class SyncStatus {
  final bool online;
  final bool syncing;
  final int pending;
  final int failed;
  final int conflicts;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncStatus({
    this.online = true,
    this.syncing = false,
    this.pending = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.lastSyncAt,
    this.lastError,
  });

  // Crea una copia del estado y actualiza únicamente los valores proporcionados.
  SyncStatus copyWith({
    bool? online,
    bool? syncing,
    int? pending,
    int? failed,
    int? conflicts,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        conflicts: conflicts ?? this.conflicts,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

// Servicio encargado de sincronizar los cambios locales con Firestore.
// Implementa el patrón Outbox: primero guarda los cambios localmente y después
// los envía al servidor cuando hay conexión.
//
// La sincronización se activa al iniciar la aplicación, registrar cambios,
// iniciar sesión, recuperar la conexión, volver a primer plano o solicitarla manualmente.
class SyncService with WidgetsBindingObserver {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const Duration _retryEvery = Duration(seconds: 30);
  static const Duration _writeTimeout = Duration(seconds: 15);
  static const int _maxAttempts = 5;

  // Notifica a la interfaz los cambios en el estado de sincronización.
  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus());

  // Emite las operaciones que Firestore ha almacenado correctamente.
  final StreamController<PendingOperation> _synced =
      StreamController<PendingOperation>.broadcast();

  // Emite las operaciones descartadas por conflictos de versiones.
  final StreamController<PendingOperation> _conflicts =
      StreamController<PendingOperation>.broadcast();

  Stream<PendingOperation> get synced => _synced.stream;
  Stream<PendingOperation> get conflicts => _conflicts.stream;

  // Cola de operaciones pendientes y lista de operaciones fallidas.
  List<PendingOperation> _queue = [];
  List<PendingOperation> _failed = [];

  bool _started = false;
  Future<void>? _loading;
  Future<void>? _running;
  bool _rerun = false;

  Timer? _timer;
  StreamSubscription<User?>? _authSub;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Carga las operaciones guardadas e inicializa los mecanismos de sincronización.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _ensureLoaded();

    WidgetsBinding.instance.addObserver(this);

    // Intenta sincronizar cuando un usuario inicia sesión.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) syncNow();
    });

    // Escucha los cambios en la conectividad.
    ConnectivityService.instance.isOnline.addListener(_onConnectivity);

    // Reintenta periódicamente mientras existan operaciones pendientes.
    _timer = Timer.periodic(_retryEvery, (_) {
      if (_queue.isNotEmpty) syncNow();
    });

    // Inicia una sincronización sin bloquear la ejecución.
    unawaited(syncNow());
  }

  @visibleForTesting
  Future<void> stop() async {
    _timer?.cancel();
    await _authSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ConnectivityService.instance.isOnline.removeListener(_onConnectivity);
    _started = false;
  }

  // Reanuda la sincronización cuando la aplicación vuelve a primer plano.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncNow();
  }

  // Actualiza el estado de conectividad que observa la interfaz.
  void _onConnectivity() {
    status.value =
        status.value.copyWith(online: ConnectivityService.instance.isOnline.value);
  }

  // Garantiza que la cola se cargue una sola vez.
  Future<void> _ensureLoaded() => _loading ??= _load();

  // Recupera las operaciones pendientes y fallidas del almacenamiento local.
  Future<void> _load() async {
    final rawQueue = await LocalStore.instance.readJson(LocalStore.outboxKey);
    final rawFailed = await LocalStore.instance.readJson(LocalStore.deadLetterKey);

    _queue = _parse(rawQueue);
    _failed = _parse(rawFailed);

    _publish();
  }

  // Convierte los datos almacenados en una lista de operaciones válidas.
  static List<PendingOperation> _parse(Object? raw) => raw is List
      ? raw.map(PendingOperation.tryFromJson).whereType<PendingOperation>().toList()
      : <PendingOperation>[];

  // Guarda las colas de operaciones pendientes y fallidas en el almacenamiento local.
  Future<void> _persist() async {
    await LocalStore.instance
        .writeJson(LocalStore.outboxKey, _queue.map((o) => o.toJson()).toList());

    await LocalStore.instance
        .writeJson(LocalStore.deadLetterKey, _failed.map((o) => o.toJson()).toList());
  }

  // Actualiza el estado global de sincronización.
  void _publish({bool? syncing, String? error, bool clearError = false}) {
    status.value = status.value.copyWith(
      pending: _queue.length,
      failed: _failed.length,
      syncing: syncing,
      lastError: error,
      clearError: clearError,
    );
  }

  // Comprueba si un documento todavía tiene cambios pendientes de sincronización.
  bool hasPending(String collection, String docId) =>
      _queue.any((o) => o.collection == collection && o.docId == docId);

  // Guarda una operación localmente y solicita su sincronización inmediata.
  Future<void> enqueue(PendingOperation op) async {
    await _ensureLoaded();

    _queue = PendingOperation.coalesce(_queue, op);

    await _persist();
    _publish();

    unawaited(syncNow());
  }

  // Devuelve las operaciones fallidas a la cola para intentar sincronizarlas nuevamente.
  Future<void> retryFailed() async {
    await _ensureLoaded();

    if (_failed.isEmpty) return;

    for (final op in _failed) {
      _queue = PendingOperation.coalesce(
          _queue, op.copyWith(attempts: 0, lastError: ''));
    }

    _failed = [];

    await _persist();
    _publish();

    await syncNow();
  }

  // Ejecuta la sincronización evitando procesos simultáneos.
  // Si llega otra solicitud durante una ejecución, programa una ejecución adicional.
  Future<void> syncNow() {
    if (_running != null) {
      _rerun = true;
      return _running!;
    }

    final run = _runLoop();
    _running = run;

    return run.whenComplete(() => _running = null);
  }

  // Repite la sincronización si llegó una nueva solicitud durante la ejecución anterior.
  Future<void> _runLoop() async {
    do {
      _rerun = false;
      await _syncOnce();
    } while (_rerun);
  }

  // Ejecuta un ciclo de sincronización de las operaciones pendientes.
  Future<void> _syncOnce() async {
    await _ensureLoaded();

    // Obtiene el usuario autenticado actualmente.
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // No sincroniza si no hay sesión o no existen operaciones de ese usuario.
    if (uid == null || !_queue.any((o) => o.ownerUid == uid)) return;

    // Verifica la conexión antes de contactar con Firestore.
    if (!await ConnectivityService.instance.check()) {
      _onConnectivity();
      return;
    }

    _publish(syncing: true, clearError: true);

    try {
      // Recorre una copia de la cola para permitir modificar la lista original.
      for (final op in List<PendingOperation>.of(_queue)) {
        // Espera hasta que el propietario de la operación inicie sesión.
        if (op.ownerUid != uid) continue;

        final outcome = await _apply(op);

        // Detiene el ciclo si se pierde la conexión.
        if (outcome == _Outcome.networkDown) break;
      }

      status.value = status.value.copyWith(lastSyncAt: DateTime.now());
    } finally {
      await _persist();
      _publish(syncing: false);
    }
  }

  // Intenta aplicar una operación en Firestore y gestiona los posibles errores.
  Future<_Outcome> _apply(PendingOperation op) async {
    try {
      final conflict = await _write(op).timeout(_writeTimeout);

      // Elimina la operación de la cola después de procesarla.
      _queue.removeWhere((q) => q.id == op.id);

      if (conflict) {
        // Registra el conflicto y notifica a los componentes interesados.
        status.value =
            status.value.copyWith(conflicts: status.value.conflicts + 1);
        _conflicts.add(op);
      } else {
        // Notifica que Firestore almacenó correctamente la operación.
        _synced.add(op);
      }

      return _Outcome.done;
    } on TimeoutException {
      ConnectivityService.instance.reportNetworkFailure();
      _publish(error: 'Sin conexión con el servidor. Se reintentará.');
      return _Outcome.networkDown;
    } on FirebaseException catch (e) {
      // Identifica los errores relacionados con problemas de conexión.
      if (_networkCodes.contains(e.code)) {
        ConnectivityService.instance.reportNetworkFailure();
        _publish(error: 'Sin conexión con el servidor. Se reintentará.');
        return _Outcome.networkDown;
      }

      // Clasifica el error y registra el fallo.
      final permanent = _permanentCodes.contains(e.code);
      _recordFailure(op, '${e.code}: ${e.message}', permanent: permanent);

      return _Outcome.failed;
    } catch (e) {
      _recordFailure(op, e.toString(), permanent: false);
      return _Outcome.failed;
    }
  }

  // Registra un fallo y decide si la operación debe reintentarse o pasar a la lista de fallidas.
  void _recordFailure(PendingOperation op, String error, {required bool permanent}) {
    final updated = op.copyWith(attempts: op.attempts + 1, lastError: error);

    _queue.removeWhere((q) => q.id == op.id);

    if (permanent || updated.attempts >= _maxAttempts) {
      _failed.add(updated);
    } else {
      _queue.add(updated);
    }

    debugPrint('Sync failed for ${op.path}: $error');
    _publish(error: 'No se pudo sincronizar un cambio.');
  }

  // Ejecuta la escritura dentro de una transacción para evitar inconsistencias.
  // Devuelve true cuando la operación pierde un conflicto de versiones.
  Future<bool> _write(PendingOperation op) {
    final ref = _db.collection(op.collection).doc(op.docId);

    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final remote = snap.data();

      // Las operaciones createOnce solo crean el documento si todavía no existe.
      if (op.kind == PendingWriteKind.createOnce) {
        if (!snap.exists) {
          tx.set(ref, {
            ..._toFirestore(op.data),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        return false;
      }

      // Compara la versión remota con la fecha de modificación local.
      final remoteVersion = remote?['clientUpdatedAt'];

      // Descarta el cambio local si el documento remoto es más reciente.
      if (op.checkConflict &&
          remoteVersion is int &&
          remoteVersion > op.clientUpdatedAt) {
        return true;
      }

      // Actualiza el documento conservando los campos que no se modificaron.
      tx.set(
        ref,
        {
          // Los valores predeterminados solo se escriben al crear el documento.
          if (!snap.exists) ..._toFirestore(op.dataIfMissing),

          // Escribe los datos principales de la operación.
          ..._toFirestore(op.data),

          // Registra la versión de la modificación local.
          'clientUpdatedAt': op.clientUpdatedAt,

          // Registra la fecha de actualización del servidor.
          'updatedAt': FieldValue.serverTimestamp(),

          // Registra la fecha de creación únicamente para documentos nuevos.
          if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return false;
    });
  }

  // Convierte todos los valores del mapa al formato compatible con Firestore.
  static Map<String, dynamic> _toFirestore(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(k, _convert(v)));

  // Convierte las fechas almacenadas en formato JSON a Timestamp de Firestore.
  // También procesa recursivamente mapas y listas.
  static Object? _convert(Object? value) {
    if (PendingOperation.isTimestamp(value)) {
      return Timestamp.fromMillisecondsSinceEpoch((value as Map)['__ts'] as int);
    }

    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convert(v)));
    }

    if (value is List) return value.map(_convert).toList();

    return value;
  }

  // Códigos de errores que indican problemas de conectividad.
  static const _networkCodes = {
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
  };

  // Códigos de errores que impiden ejecutar la operación permanentemente.
  static const _permanentCodes = {
    'permission-denied',
    'invalid-argument',
    'not-found',
  };
}

// Resultados posibles al intentar sincronizar una operación.
enum _Outcome { done, failed, networkDown }