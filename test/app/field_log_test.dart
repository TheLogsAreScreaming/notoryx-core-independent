import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/field_log.dart';
import 'package:notoryx_core/app/refresh_rate.dart';
import 'package:notoryx_core/data/data.dart';

Message _m({
  bool outgoing = false,
  MessageKind kind = MessageKind.channel,
  String? sender = 'Bob',
}) => Message(
  id: 1,
  radioKey: 'r',
  kind: kind,
  thread: 'c:1',
  outgoing: outgoing,
  body: 'Hello',
  senderName: sender,
  sentAt: 0,
  storedAt: DateTime(2026, 11, 8, 9, 5).millisecondsSinceEpoch,
  status: MessageStatus.values.first,
  attempts: 0,
  textType: 0,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a brief reads as one message and skips empty parts', () {
    const full = TripBrief(
      where: 'Black Rock',
      backBy: 'Sat 6 pm',
      people: 'Sam, Alex',
      notes: 'Car at north lot',
    );
    expect(
      full.text,
      'Trip brief: Going to Black Rock. Back by Sat 6 pm. '
      'People: Sam, Alex. Car at north lot',
    );
    expect(const TripBrief(where: 'Ridge').text, 'Trip brief: Going to Ridge.');
    expect(const TripBrief(where: '  ').isEmpty, isTrue);
  });

  test('a brief survives saving, and damage reads as empty', () {
    const b = TripBrief(where: 'A', backBy: 'B', people: 'C', notes: 'D');
    final again = TripBrief.fromJson(b.toJson());
    expect(again.text, b.text);
    expect(TripBrief.fromJson('not json').isEmpty, isTrue);
    expect(TripBrief.fromJson(null).isEmpty, isTrue);
  });

  test('log lines say who and where', () {
    expect(
      fieldLogLine(_m(), 'Hike'),
      '2026-11-08 09:05  From Bob on Hike: Hello',
    );
    expect(
      fieldLogLine(_m(outgoing: true), 'Hike'),
      '2026-11-08 09:05  Sent to Hike: Hello',
    );
    expect(
      fieldLogLine(_m(kind: MessageKind.direct, sender: null), 'Alice'),
      '2026-11-08 09:05  From Alice: Hello',
    );
  });

  test('battery saver reads less often than normal', () {
    expect(RefreshRate.saver.sensors > RefreshRate.normal.sensors, isTrue);
    expect(
      RefreshRate.saver.noiseFloor > RefreshRate.normal.noiseFloor,
      isTrue,
    );
  });
}
