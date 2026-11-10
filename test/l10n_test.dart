import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> read(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, Object?>;

  test('every language has every string, with the same placeholders', () {
    final en = read('en');
    final placeholder = RegExp(r'\{\w+\}');
    for (final lang in ['es']) {
      final other = read(lang);
      for (final MapEntry(:key, :value) in en.entries) {
        if (key.startsWith('@')) continue;
        expect(other, contains(key), reason: '$lang is missing $key');
        expect(
          placeholder
              .allMatches(other[key]! as String)
              .map((m) => m[0])
              .toSet(),
          placeholder.allMatches(value! as String).map((m) => m[0]).toSet(),
          reason: '$lang $key',
        );
      }
    }
  });
}
