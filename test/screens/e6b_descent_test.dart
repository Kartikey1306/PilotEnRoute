/// The E6B DESCENT tab, driven through the real widgets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/e6b_screen.dart';

Future<void> openTab(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(1600, 2200);
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

void main() {
  Future<void> fill(WidgetTester tester, String from, String to) async {
    await openTab(tester, 'DESCENT');
    await type(tester, 'Current Altitude', from);
    await type(tester, 'Target Altitude', to);
    await type(tester, 'Groundspeed', '120');
  }

  testWidgets('3° from 6,500 to 1,500 ft at 120 kt: start 15.7 nm out at '
      '637 fpm', (tester) async {
    await fill(tester, '6500', '1500');
    expect(find.text('15.7 nm'), findsOneWidget);
    expect(find.text('637 fpm'), findsOneWidget);
    expect(find.text('7:51'), findsOneWidget);
    expect(find.text('5,000 ft'), findsOneWidget);
  });

  testWidgets('by rate: 500 fpm gives 20 nm, 10:00 and a 2.4° path',
      (tester) async {
    await fill(tester, '6500', '1500');
    await tester.tap(find.text('BY RATE'));
    await tester.pump();
    expect(find.text('20.0 nm'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('2.4°'), findsOneWidget);
  });

  testWidgets('a target above the current altitude says why', (tester) async {
    await fill(tester, '1500', '6500');
    expect(find.byKey(const Key('descent-problem')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^[0-9].* nm$')), findsNothing);
    expect(find.text('—'), findsWidgets);
  });
}
