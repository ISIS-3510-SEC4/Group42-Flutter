import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/analytics_event.dart';

abstract class AnalyticsRepository {
  Future<void> saveEvent(AnalyticsEvent event);
}

class FirestoreAnalyticsRepository implements AnalyticsRepository {
  FirestoreAnalyticsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      (_firestore ??= FirebaseFirestore.instance).collection('analytics_events');

  @override
  Future<void> saveEvent(AnalyticsEvent event) =>
      _events.doc(event.id).set(event.toMap());
}
