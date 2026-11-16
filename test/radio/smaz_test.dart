import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

void main() {
  group('SMAZ', () {
    test('uses the standard codebook', () {
      // "the" is code 1 and " " code 0 in antirez's table.
      expect(smazCompress(utf8.encode('the')), [1]);
      expect(smazCompress(utf8.encode(' the')), [13, 2]);
    });

    test('bytes not in the codebook go out as literals', () {
      expect(smazCompress(utf8.encode('Q')), [254, 0x51]);
      expect(smazCompress(utf8.encode('QQ')), [255, 1, 0x51, 0x51]);
    });

    test('round trips any text, including long literal runs', () {
      for (final text in [
        'snow line is down to 5,000 ft',
        'Meet at the trailhead at 7, bring water',
        'ünïcödé 日本語 📡',
        'xyzq' * 100,
        '\r\n\r\nline\n',
      ]) {
        final packed = smazCompress(utf8.encode(text));
        expect(utf8.decode(smazDecompress(packed)!), text);
      }
    });

    test('broken SMAZ is refused', () {
      expect(smazDecompress([254]), isNull);
      expect(smazDecompress([255, 5, 1, 2]), isNull);
    });
  });

  group('on the air', () {
    test('wraps only when it saves space', () {
      final wrapped = smazWrap('the weather is clear on the ridge tonight');
      expect(wrapped, startsWith('s:'));
      expect(
        utf8.encode(wrapped).length,
        lessThan('the weather is clear on the ridge tonight'.length),
      );
      expect(smazWrap('ok'), 'ok');
      expect(smazWrap('s:already'), 's:already');
    });

    test('unwraps what it wraps', () {
      const text = 'the weather is clear on the ridge tonight';
      expect(smazUnwrap(smazWrap(text)), text);
    });

    test('accepts missing padding and URL-safe base64', () {
      const text = 'the weather is clear on the ridge tonight';
      final wrapped = smazWrap(text);
      final loose = wrapped
          .replaceAll('=', '')
          .replaceAll('+', '-')
          .replaceAll('/', '_');
      expect(smazUnwrap(loose), text);
    });

    test('leaves ordinary messages that start with s: alone', () {
      for (final text in ['s: hi', 's:ok', 's:', 's:hello there', 'status']) {
        expect(smazUnwrap(text), isNull, reason: text);
      }
    });
  });
}
