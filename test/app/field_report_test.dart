import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/field_report.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  List<String> blank(ReportTemplate t) => List.filled(t.fields.length, '');

  test('a short report is one message and skips empty lines', () {
    final v = blank(saluteReport);
    v[0] = '4 people';
    v[2] = ' north gate ';
    expect(reportMessages(saluteReport, v), [
      'SALUTE S:4 people | L:north gate',
    ]);
  });

  test('nothing filled in means nothing to send', () {
    expect(reportMessages(saluteReport, blank(saluteReport)), isEmpty);
  });

  test('a long report splits between fields, every part fits', () {
    final v = List.filled(nineLineReport.fields.length, 'x' * 40);
    final messages = reportMessages(nineLineReport, v)!;
    expect(messages.length, greaterThan(1));
    expect(messages.first, startsWith('9-LINE 1/${messages.length} 1:'));
    for (final m in messages) {
      expect(utf8.encode(m).length, lessThanOrEqualTo(maxDirectTextBytes));
    }
    for (var i = 1; i <= 9; i++) {
      expect(messages.join(' '), contains('$i:${'x' * 40}'));
    }
  });

  test('a field too long for any message is refused', () {
    final v = blank(saluteReport);
    v[1] = 'x' * 200;
    expect(reportMessages(saluteReport, v), isNull);
  });
}
