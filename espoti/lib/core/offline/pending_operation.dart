import 'package:uuid/uuid.dart';

// Define cómo se aplica una escritura pendiente en Firestore.
enum PendingWriteKind {

  upsert,
  createOnce,
}

// Representa un cambio local que está esperando ser enviado a Firestore.
// Cada instancia corresponde a una operación dentro de la cola local
class PendingOperation {

  final String id;
  final PendingWriteKind kind;
  final String collection;
  final String docId;
  final String ownerUid;


  final Map<String, dynamic> data;
  final Map<String, dynamic> dataIfMissing;
  final int clientUpdatedAt;
  final bool checkConflict;

  // Número de veces que se ha intentado ejecutar la operación.
  final int attempts;

  // Último error registrado durante el intento de sincronización.
  final String? lastError;

  // Constructor de la operación pendiente.
  const PendingOperation({
    required this.id,
    required this.kind,
    required this.collection,
    required this.docId,
    required this.ownerUid,
    required this.data,
    this.dataIfMissing = const {},
    required this.clientUpdatedAt,
    this.checkConflict = false,
    this.attempts = 0,
    this.lastError,
  });

  // Fábrica que crea una operación pendiente con valores iniciales.
  factory PendingOperation.create({
    required PendingWriteKind kind,
    required String collection,
    required String docId,
    required String ownerUid,
    required Map<String, dynamic> data,
    Map<String, dynamic> dataIfMissing = const {},
    bool checkConflict = false,
    DateTime? now,
  }) =>
      PendingOperation(

        id: const Uuid().v4(),
        kind: kind,
        collection: collection,
        docId: docId,
        ownerUid: ownerUid,
        data: data,
        dataIfMissing: dataIfMissing,
        clientUpdatedAt: (now ?? DateTime.now()).millisecondsSinceEpoch,
        checkConflict: checkConflict,
      );

  String get path => '$collection/$docId';

  static Map<String, int> timestamp(DateTime value) =>
      {'__ts': value.millisecondsSinceEpoch};

  // Comprueba si un objeto corresponde al formato de fecha definido anteriormente.
  // Verifica que sea un mapa con una única clave llamada __ts y un valor entero.
  static bool isTimestamp(Object? value) =>
      value is Map && value.length == 1 && value['__ts'] is int;

  // Crea una nueva instancia de PendingOperation conservando los valores
  // originales y reemplazando únicamente los campos que se proporcionen.
  PendingOperation copyWith({
    Map<String, dynamic>? data,
    Map<String, dynamic>? dataIfMissing,
    int? clientUpdatedAt,
    bool? checkConflict,
    int? attempts,
    String? lastError,
  }) =>
      PendingOperation(

        id: id,
        kind: kind,
        collection: collection,
        docId: docId,
        ownerUid: ownerUid,
        data: data ?? this.data,
        dataIfMissing: dataIfMissing ?? this.dataIfMissing,
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        checkConflict: checkConflict ?? this.checkConflict,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
      );

  // Convierte la operación pendiente en un mapa JSON.
  // Permite guardar la operación localmente o transmitirla entre componentes.
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'collection': collection,
        'docId': docId,
        'ownerUid': ownerUid,
        'data': data,
        'dataIfMissing': dataIfMissing,
        'clientUpdatedAt': clientUpdatedAt,
        'checkConflict': checkConflict,
        'attempts': attempts,
        'lastError': lastError,
      };

  // Intenta reconstruir una operación pendiente a partir de un objeto JSON.
  // Devuelve null si los datos no tienen el formato esperado.
  static PendingOperation? tryFromJson(Object? json) {

    if (json is! Map) return null;

    try {
      return PendingOperation(
        id: json['id'] as String,
        kind: PendingWriteKind.values.byName(json['kind'] as String),
        collection: json['collection'] as String,
        docId: json['docId'] as String,
        ownerUid: json['ownerUid'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        dataIfMissing:
            Map<String, dynamic>.from((json['dataIfMissing'] as Map?) ?? const {}),

        // Recupera la fecha de modificación.
        clientUpdatedAt: json['clientUpdatedAt'] as int,

        checkConflict: json['checkConflict'] as bool? ?? false,
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );

    } catch (_) {

      return null;
    }
  }

  // Combina una operación nueva con las operaciones que ya están en la cola.

  // Si existe otro upsert del mismo documento y usuario, combina sus datos.
  //    Los valores nuevos sobrescriben los anteriores y se conserva la posición.
  // Si existe otro createOnce del mismo documento y usuario, ignora la nueva operación.
  // Si no existe una operación equivalente, agrega la nueva al final de la cola.
  static List<PendingOperation> coalesce(
      List<PendingOperation> queue, PendingOperation op) {


    final index = queue.indexWhere((q) =>
        q.path == op.path && q.kind == op.kind && q.ownerUid == op.ownerUid);


    if (index == -1) return [...queue, op];

    if (op.kind == PendingWriteKind.createOnce) return queue;

    final queued = queue[index];


    final merged = queued.copyWith(
     
      data: {...queued.data, ...op.data},
      dataIfMissing: {...queued.dataIfMissing, ...op.dataIfMissing},
      clientUpdatedAt: op.clientUpdatedAt,
      checkConflict: queued.checkConflict || op.checkConflict,
    );

    // Devuelve una nueva lista reemplazando la operación existente
    // por la versión combinada, sin modificar la posición original.
    return [...queue]..[index] = merged;
  }
}