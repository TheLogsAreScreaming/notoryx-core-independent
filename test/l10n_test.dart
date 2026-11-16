import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> read(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, Object?>;

  final languages = [
    for (final f in Directory('lib/l10n').listSync())
      if (RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)?[1] case final l?
          when l != 'en')
        l,
  ];

  test('every language has every string, with the same placeholders', () {
    final en = read('en');
    for (final lang in languages) {
      final other = read(lang);
      for (final MapEntry(:key, :value) in en.entries) {
        if (key.startsWith('@') || value is! String) continue;
        expect(other, contains(key), reason: '$lang is missing $key');
        final text = other[key]! as String;
        final meta = en['@$key'];
        final names = meta is Map && meta['placeholders'] is Map
            ? (meta['placeholders'] as Map).keys.cast<String>()
            : const <String>[];
        for (final name in names) {
          expect(
            RegExp('\\{$name[},]').hasMatch(text),
            isTrue,
            reason: '$lang $key is missing {$name}',
          );
        }
      }
    }
  });
}
