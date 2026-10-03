import 'package:flutter_test/flutter_test.dart';
import 'package:espoti/core/services/activity_context_service.dart';
import 'package:espoti/core/services/location_sharing_service.dart';

void main() {
  test('motion state starts unknown before the sensor is started', () {
    expect(ActivityContextService().state, MotionState.unknown);
  });

  test('location sharing is idle outside an active meeting', () {
    expect(LocationSharingService().statusNotifier.value,
        LocationSyncStatus.idle);
  });
}
