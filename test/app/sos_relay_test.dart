import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/sos_relay.dart';
import 'package:pointycastle/export.dart';

void main() {
  final secret = Uint8List.fromList(List.generate(16, (i) => i + 1));
  final secrets = {1: secret};
  final t0 = DateTime(2026, 11, 9, 12);
  const sentAt = 1700000000;

  Uint8List payload() {
    final plain = Uint8List(16)
      ..buffer.asByteData().setUint32(0, sentAt, Endian.little);
    final cipher = Uint8List(16);
    (AESEngine()..init(true, KeyParameter(secret))).processBlock(
      plain,
      0,
      cipher,
      0,
    );
    return Uint8List.fromList([
      sha256.convert(secret).bytes.first,
      9,
      9,
      ...cipher,
    ]);
  }

  // Flood (route 1), group text (type 5), then path length and path.
  Uint8List packet({int hops = 0}) => Uint8List.fromList([
    (5 << 2) | 1,
    hops,
    for (var i = 0; i < hops; i++) 0xA0 + i,
    ...payload(),
  ]);

  test('recognises the app’s own SOS text only', () {
    expect(isSosPost('SOS - I need help. Position unknown'), isTrue);
    expect(isSosPost('SOS (3) - I need help.'), isTrue);
    expect(isSosPost('Is anyone doing an SOS drill?'), isFalse);
    expect(isSosPost("I'm safe now - SOS over."), isFalse);
  });

  test('a direct SOS nobody repeats is relayed once, after the wait', () {
    final relay = SosRelay()..heard(packet(), secrets, t0);
    relay.received(slot: 1, sentAt: sentAt, body: 'SOS - help', now: t0);
    expect(relay.due(t0.add(const Duration(seconds: 3))), isEmpty);
    final out = relay.due(t0.add(sosRelayWait));
    expect(out, hasLength(1));
    expect(out.single, packet());
    expect(relay.due(t0.add(const Duration(minutes: 1))), isEmpty);
  });

  test('not relayed when a repeater passed it on', () {
    final relay = SosRelay()..heard(packet(), secrets, t0);
    relay.received(slot: 1, sentAt: sentAt, body: 'SOS - help', now: t0);
    relay.heard(packet(hops: 1), secrets, t0.add(const Duration(seconds: 2)));
    expect(relay.due(t0.add(sosRelayWait)), isEmpty);
  });

  test('not relayed when it only arrived through a repeater', () {
    final relay = SosRelay()..heard(packet(hops: 2), secrets, t0);
    relay.received(slot: 1, sentAt: sentAt, body: 'SOS - help', now: t0);
    expect(relay.due(t0.add(sosRelayWait)), isEmpty);
  });

  test('ordinary posts are never relayed', () {
    final relay = SosRelay()..heard(packet(), secrets, t0);
    relay.received(slot: 1, sentAt: sentAt, body: 'lunch?', now: t0);
    expect(relay.due(t0.add(sosRelayWait)), isEmpty);
  });
}
