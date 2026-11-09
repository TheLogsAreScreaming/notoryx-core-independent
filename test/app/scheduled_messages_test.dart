import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/chat_send.dart';
import 'package:notoryx_core/app/scheduled_messages.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  final at = DateTime(2026, 11, 9, 12);
  final m = ScheduledMessage(
    id: 1,
    radioKey: 'r',
    thread: 'c:1',
    title: '#trail',
    text: 'hi',
    at: at,
  );

  test('due at its time, missed after the grace period', () {
    expect(m.isDue(at.subtract(const Duration(seconds: 1))), isFalse);
    expect(m.isDue(at), isTrue);
    expect(m.isMissed(at.add(scheduledGrace)), isFalse);
    expect(
      m.isMissed(at.add(scheduledGrace + const Duration(minutes: 1))),
      isTrue,
    );
  });

  test('survives saving', () {
    final back = ScheduledMessage.fromJson(
      jsonDecode(jsonEncode(m.toJson())) as Map<String, Object?>,
    );
    expect(back.at, at);
    expect(back.thread, 'c:1');
  });

  test('forward text fits one message without splitting an emoji', () {
    expect(forwardText('Sam', 'hello'), 'Fwd Sam: hello');
    final long = forwardText('Sam', '😀' * 100);
    expect(utf8.encode(long).length, lessThanOrEqualTo(maxDirectTextBytes));
    expect(long, endsWith('😀…'));
  });
}
