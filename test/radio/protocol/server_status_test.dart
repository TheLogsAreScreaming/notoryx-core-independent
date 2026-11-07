import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../../support/radio_frames.dart';

void main() {
  test('reads a repeater status block', () {
    final s = ServerStatus.parse(repeaterStatusBlock())!;
    expect(s.batteryMillivolts, 4100);
    expect(s.noiseFloor, -110);
    expect(s.lastRssi, -85);
    expect(s.lastSnr, 6.5);
    expect(s.upTimeSeconds, 90061);
    expect(
      (s.sentFlood, s.sentDirect, s.receivedFlood, s.receivedDirect),
      (400, 500, 700, 500),
    );
    expect(s.receiveAirTimeSeconds, 800);
    expect(s.receiveErrors, 5);
    expect(s.posts, isNull);
  });

  test('reads a room server status block', () {
    final block = [
      ...repeaterStatusBlock().sublist(0, 48),
      ...u16(12),
      ...u16(30),
    ];
    final s = ServerStatus.parse(block)!;
    expect(s.posts, 12);
    expect(s.postPushes, 30);
    expect(s.receiveErrors, isNull);
  });

  test('too short is not a status', () {
    expect(ServerStatus.parse(List.filled(47, 0)), isNull);
  });
}
