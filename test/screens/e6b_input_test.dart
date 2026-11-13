/// E6B input handling: comma decimals, impossible answers and minus signs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/e6b_screen.dart';

Future<void> openTab(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: E6BScreen()));
  await tester.pump();
  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextField, label), value);
  await tester.pump();
}

String fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

void main() {
  testWidgets('a comma decimal (de/fr/es keypads) reads as a point',
      (tester) async {
    await openTab(tester, 'TAS / DA');
    await type(tester, 'Field Elevation', '1000');
    await type(tester, 'Altimeter Setting', '29,42');
    // 29.42 inHg → PA 1,500 ft (it used to read "2942" → −2.9 million ft).
    expect(find.text('1,500 ft'), findsOneWidget);
  });

  testWidgets('an altimeter typed in hPa is not taken as inHg',
      (tester) async {
    await openTab(tester, 'TAS / DA');
    await type(tester, 'Field Elevation', '1000');
    await type(tester, 'Altimeter Setting', '1013');
    expect(find.textContaining('-1,'), findsNothing);
    expect(find.textContaining('982,'), findsNothing);
  });

  testWidgets('a headwind stronger than TAS has no solution, not "GS 0 kt"',
      (tester) async {
    await openTab(tester, 'WIND');
    await type(tester, 'True Course', '360');
    await type(tester, 'True Airspeed', '50');
    await type(tester, 'Wind Direction (from)', '360');
    await type(tester, 'Wind Speed', '60');
    expect(find.text('0 kt'), findsNothing);
    expect(find.text('0°'), findsNothing);
  });

  testWidgets('a minus sign cannot be typed into an unsigned field',
      (tester) async {
    await openTab(tester, 'WIND');
    await type(tester, 'Wind Speed', '-20');
    expect(fieldText(tester, 'Wind Speed'), '20');
  });

  testWidgets('…but can where a value is really negative (OAT)',
      (tester) async {
    await openTab(tester, 'TAS / DA');
    await type(tester, 'Outside Air Temp (OAT)', '-15');
    expect(fieldText(tester, 'Outside Air Temp (OAT)'), '-15');
  });
}
