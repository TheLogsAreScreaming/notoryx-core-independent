import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

void main() {
  test('a flooded advert names its sender key and the repeaters so far', () {
    final raw = Uint8List.fromList([
      (PayloadKind.advert.value << 2) | 1, // flood
      2, 0x11, 0x22, // two 1-byte hops
      ...List.filled(32, 0x42), // sender key
      ...List.filled(70, 0), // timestamp, signature, app data
    ]);
    final h = PacketHeader.parse(raw)!;
    expect(h.route, RouteKind.flood);
    expect(h.payload, PayloadKind.advert);
    expect(h.hops, ['11', '22']);
    expect(h.advertKey, '42' * 32);
    expect(h.payloadLength, 102);
  });

  test('transport codes are skipped before the path', () {
    final raw = Uint8List.fromList([
      (PayloadKind.groupText.value << 2) | 0, // transport flood
      1, 2, 3, 4, // transport codes
      0x41, 0xaa, 0xbb, // one 2-byte hop
      0x9c, 1, 2, 3,
    ]);
    final h = PacketHeader.parse(raw)!;
    expect(h.route, RouteKind.transportFlood);
    expect(h.hashBytes, 2);
    expect(h.hops, ['aabb']);
    expect(h.channelHash, 0x9c);
  });

  test('direct text with no hops left', () {
    final h = PacketHeader.parse(
      Uint8List.fromList([(PayloadKind.text.value << 2) | 2, 0, 1, 2, 3]),
    )!;
    expect(h.route, RouteKind.direct);
    expect(h.payload, PayloadKind.text);
    expect(h.hopCount, 0);
  });

  test('truncated packets are not read', () {
    expect(PacketHeader.parse(Uint8List.fromList([5])), isNull);
    expect(PacketHeader.parse(Uint8List.fromList([5, 3, 1])), isNull);
  });
}
