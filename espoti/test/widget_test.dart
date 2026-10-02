import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:espoti/app/app.dart';

void main() {
  testWidgets('Welcome screen shows the Espoti tagline', (WidgetTester tester) async {
    await tester.pumpWidget(const EspotiApp());

    expect(find.text('Where do we meet?'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
