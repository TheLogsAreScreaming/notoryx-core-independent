import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/protocol/commands.dart';
import 'package:notoryx_core/radio/protocol/region_scope.dart';
import 'package:pointycastle/export.dart';

void main() {
  final payload = Uint8List.fromList([0xAB, 1, 2, 3, 4, 5]);
  // Worked out separately with Python's hashlib and hmac.
  const keyHex = '2461d91f22249a7e39fe621b74dd6e85';
  const code = 12783;

  Uint8List packet(int low, int high, {int route = 0}) => Uint8List.fromList([
    (5 << 2) | route,
    if (route == 0) ...[low, high, 0, 0],
    0,
    ...payload,
  ]);

  test('region key and code match the firmware recipe', () {
    final key = regionKey('#CT ');
    expect(key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), keyHex);
    expect(regionCode(key, 5, payload), code);
  });

  test('a scoped post is matched only to its own region', () {
    final raw = packet(code & 0xFF, code >> 8);
    expect(scopedPost(raw, const ['ny', 'ct'])?.region, 'ct');
    expect(scopedPost(raw, const ['ny']), isNull);
    expect(scopedPost(packet(0, 0, route: 1), const ['ct']), isNull);
  });

  test('the post time comes out of the encrypted block', () {
    final secret = Uint8List.fromList(List.generate(16, (i) => i + 1));
    final plain = Uint8List(16)
      ..buffer.asByteData().setUint32(0, 1700000000, Endian.little);
    final cipher = Uint8List(16);
    (AESEngine()..init(true, KeyParameter(secret))).processBlock(
      plain,
      0,
      cipher,
      0,
    );
    final post = Uint8List.fromList([0xAB, 9, 9, ...cipher]);
    expect(channelPostTime(post, secret), 1700000000);
    expect(channelPostTime(Uint8List(5), secret), isNull);
  });

  test('the scope command sets a key and clears it', () {
    final key = regionKey('ct');
    expect(SetFloodScope(key).encode(), [54, 0, ...key]);
    expect(const SetFloodScope(null).encode(), [54, 0]);
  });

  test('region lists are tidied', () {
    expect(regionNames(' #CT, ny  ct,'), ['ct', 'ny']);
    expect(cleanRegionName('  '), isNull);
  });
}
