import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/server_history.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/radio_frames.dart';

Message _reply(String body, DateTime at) => Message(
  id: 1,
  radioKey: 'r',
  kind: MessageKind.direct,
  thread: 'd:ab',
  outgoing: false,
  body: body,
  sentAt: 0,
  storedAt: at.millisecondsSinceEpoch,
  status: MessageStatus.received,
  attempts: 0,
  textType: 1,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MeshDatabase db;
  setUp(() => db = MeshDatabase.inMemory());
  tearDown(() => db.close());

  test('status replies are kept per server, in order, a month long', () async {
    final store = MeshStore(db);
    final status = ServerStatus.parse(repeaterStatusBlock())!;
    final now = DateTime(2026, 11, 22, 12);
    await keepServerCheck(
      store,
      'radio',
      'aa',
      status,
      now.subtract(const Duration(days: 40)),
    );
    await keepServerCheck(store, 'radio', 'aa', status, now);
    await keepServerCheck(
      store,
      'radio',
      'aa',
      status,
      now.subtract(const Duration(hours: 1)),
    );
    final list = await loadServerChecks(store, 'radio', 'aa');
    expect(list.map((c) => c.at), [
      now.subtract(const Duration(hours: 1)),
      now,
    ]);
    expect(
      serverValue(list.last, ServerValue.battery),
      status.batteryMillivolts / 1000,
    );
    expect(serverValue(list.last, ServerValue.snr), status.lastSnr);
    expect(await loadServerChecks(store, 'radio', 'bb'), isEmpty);
  });

  test('neighbour SNR comes from every kept Neighbours reply', () {
    final t = DateTime(2026, 11, 22, 12);
    final lines = [
      _reply('> AB12:30:24\nCD34:10:-8', t),
      _reply('> AB12:90:24', t.add(const Duration(minutes: 1))),
      _reply('not a neighbour list', t),
      _reply('> AB12:5:12', t.add(const Duration(hours: 1))),
    ];
    final trail = neighborSnrTrail(lines, 'ab12');
    expect(trail.map((p) => p.value), [6, 3]);
    expect(trail.first.at, t.subtract(const Duration(seconds: 30)));
    expect(neighborSnrTrail(lines, 'cd34').single.value, -2);
    expect(neighborSnrTrail(lines, 'ef56'), isEmpty);
  });
}
