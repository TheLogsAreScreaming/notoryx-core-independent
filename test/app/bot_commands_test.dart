import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/bot_commands.dart';

void main() {
  test('sunrise and sunset match the almanac within ten minutes', () {
    // New York, 21 June 2026: about 09:25 and 00:31 (next day) UTC.
    final s = sunTimes(DateTime.utc(2026, 6, 21), 40.7128, -74.006);
    expect(
      s.rise!.difference(DateTime.utc(2026, 6, 21, 9, 25)).inMinutes.abs(),
      lessThan(10),
    );
    final set = s.set!;
    final setMinutes = set.hour * 60 + set.minute;
    expect((setMinutes - 31).abs(), lessThan(10));
  });

  test('polar night has no sunrise', () {
    final s = sunTimes(DateTime.utc(2026, 12, 21), 78.2, 15.6);
    expect(s.rise, isNull);
    expect(s.set, isNull);
  });

  test('moon phase: new and full', () {
    expect(moonPhase(DateTime.utc(2000, 1, 6, 18, 14)), closeTo(0, 0.01));
    expect(moonText(DateTime.utc(2000, 1, 21, 4, 40)), startsWith('🌕'));
  });

  test('dice: default, NdM, and refused sizes', () {
    final rng = Random(1);
    expect(diceText('', rng), matches(RegExp(r'^🎲 [1-6] \(d6\)$')));
    expect(
      diceText('3d6', rng),
      matches(RegExp(r'^🎲 \d+ \(\d \+ \d \+ \d\)$')),
    );
    expect(diceText('50d6', rng), isNull);
    expect(diceText('d1', rng), isNull);
    expect(diceText('hello', rng), isNull);
  });

  test('ping and trace describe how a message came', () {
    expect(
      botCommandReply('!ping', pathLength: 2, snr: 6.25, now: DateTime(2026)),
      'pong. Your message came through 2 repeaters, last hop 6.3 dB.',
    );
    expect(
      botCommandReply('!trace', pathLength: 0, snr: null, now: DateTime(2026)),
      'Your message came straight to my radio.',
    );
  });

  test('not a command, unknown command, and no position', () {
    final now = DateTime(2026);
    expect(botCommandReply('ping', pathLength: 0, snr: 0, now: now), isNull);
    expect(botCommandReply('!nope', pathLength: 0, snr: 0, now: now), isNull);
    expect(
      botCommandReply('!sun', pathLength: 0, snr: 0, now: now),
      'My radio has no position set.',
    );
    expect(
      botCommandReply('!help', pathLength: 0, snr: 0, now: now),
      contains('!moon'),
    );
  });
}
