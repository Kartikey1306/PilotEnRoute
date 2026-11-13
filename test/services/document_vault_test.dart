/// The document vault keeps every stored record and counts days in calendar
/// days, whatever the clocks do.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/document_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PilotDocument doc(DateTime? expiry) => PilotDocument(
        id: 'a',
        title: 'Medical',
        category: DocCategory.fromLabel(null),
        filePath: '/x/medical.pdf',
        addedDate: DateTime(2026, 1, 1),
        expiryDate: expiry,
      );

  test('one damaged record does not cost the others, and survives a save',
      () async {
    final good = doc(null).toJson();
    final broken = {'id': 'b', 'title': 42}; // title is not a string
    SharedPreferences.setMockInitialValues({
      DocumentService.prefsKey: jsonEncode([good, broken]),
    });
    final s = DocumentService();
    await s.init();
    expect(s.documents.map((d) => d.id), ['a']);
    expect(s.unreadableCount, 1);

    await s.updateMetadata('a', title: 'Medical 3rd class');
    final saved = jsonDecode((await SharedPreferences.getInstance())
        .getString(DocumentService.prefsKey)!) as List;
    expect(saved, hasLength(2));
    expect(saved.last, broken);
  });

  test('unreadable storage is kept aside, not overwritten', () async {
    SharedPreferences.setMockInitialValues(
        {DocumentService.prefsKey: '[{"id": "a", '});
    final s = DocumentService();
    await s.init();
    expect(s.documents, isEmpty);
    expect((await SharedPreferences.getInstance())
        .getString('${DocumentService.prefsKey}_unreadable'),
        '[{"id": "a", ');
  });

  test('days until expiry are calendar days', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final n in [-1, 0, 1, 30, 31, 122, 400]) {
      final d = doc(DateTime(today.year, today.month, today.day + n));
      expect(d.daysUntilExpiry, n, reason: '$n days');
      expect(d.isExpired, n < 0);
      expect(d.isExpiringSoon, n <= 30);
    }
  });
}
