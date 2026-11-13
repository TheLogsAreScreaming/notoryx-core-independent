import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/scripted_radio.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;
  late MeshStore store;
  late MeshSync sync;
  late String key;
  final alice = PublicKey(List.filled(32, 1));

  setUp(() async {
    final link = FakeRadioLink();
    ScriptedRadio(link);
    db = MeshDatabase.inMemory();
    store = MeshStore(db);
    sync = MeshSync(RadioSession(link), store);
    key = (await sync.start(now: DateTime.utc(2026, 11, 13))).key;
  });

  tearDown(() async {
    await sync.stop();
    await db.close();
  });

  test('a chosen route is stored on the radio and read back', () async {
    await sync.setRoute(alice, [0x11, 0x22], hashBytes: 1);
    var row = (await store.contact(key, alice.hex))!;
    expect(row.outPathLength, 2);
    expect(row.outPath.sublist(0, 2), [0x11, 0x22]);
    expect(row.name, 'Alice', reason: 'nothing else changes');

    await sync.setRoute(alice, [1, 2, 3, 4], hashBytes: 2);
    row = (await store.contact(key, alice.hex))!;
    expect(row.outPathLength, 0x40 | 2);

    await sync.setRoute(alice, const [], hashBytes: 1);
    row = (await store.contact(key, alice.hex))!;
    expect(row.outPathLength, 0, reason: 'direct');
  });

  test('routes the radio cannot hold are refused before sending', () async {
    expect(
      () => sync.setRoute(alice, [1, 2, 3], hashBytes: 2),
      throwsArgumentError,
    );
    expect(
      () => sync.setRoute(alice, List.filled(66, 1), hashBytes: 1),
      throwsArgumentError,
    );
    expect(
      () => sync.setRoute(alice, [1, 2, 3, 4], hashBytes: 4),
      throwsArgumentError,
    );
  });
}
