import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/schema_rollback.dart';
import '../support/scripted_radio.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final repeater = PublicKey(List.filled(32, 0x42));
  late ScriptedRadio radio;
  late MeshDatabase db;
  late MeshStore store;
  late MeshSync sync;
  late String key;

  setUp(() async {
    final link = FakeRadioLink();
    radio = ScriptedRadio(link)
      ..contacts.add(
        contactFrame(
          'Hill RPT',
          keyByte: 0x42,
          type: NodeType.repeater,
          lastModified: 11,
        ),
      );
    db = MeshDatabase.inMemory();
    store = MeshStore(db);
    sync = MeshSync(
      RadioSession(link),
      store,
      serverReplyFloor: const Duration(milliseconds: 200),
      selfTelemetryWait: const Duration(milliseconds: 200),
    );
    key = (await sync.start(now: DateTime.utc(2026, 11, 7))).key;
  });

  tearDown(() async {
    await sync.stop();
    await db.close();
  });

  test('the radio reports itself and the reading is saved', () async {
    final readings = await sync.requestTelemetry();
    expect(readings, [
      const LppReading(1, LppKind.voltage, [4.06]),
    ]);
    expect(radio.telemetryRequests.single, [39, 0, 0, 0]);

    final saved = await store.watchTelemetry(key, key).first;
    expect(saved, hasLength(1));
    expect(decodeLpp(saved.single.data).single.value, 4.06);
  });

  test('a node that answers is saved under its own key', () async {
    radio.nodeTelemetry[0x42] = [1, 116, 0x01, 0x80, 2, 103, 0x00, 0xC8];
    final readings = await sync.requestTelemetry(repeater);
    expect(readings!.map((r) => r.value), [3.84, 20.0]);
    expect(radio.telemetryRequests.single.sublist(4), repeater.bytes);
    expect(await store.watchTelemetry(key, repeater.hex).first, hasLength(1));
    expect(await store.watchTelemetry(key, key).first, isEmpty);
  });

  test('silence (not logged in, out of range) gives null', () async {
    expect(await sync.requestTelemetry(repeater), isNull);
    expect(await store.watchTelemetry(key, repeater.hex).first, isEmpty);
  });

  test('history keeps the newest readings only', () async {
    for (var i = 0; i < MeshStore.telemetryKept + 5; i++) {
      await store.saveTelemetry(key, 'n', [1, 116, 0, i & 0xFF]);
    }
    final rows = await store.watchTelemetry(key, 'n').first;
    expect(rows, hasLength(MeshStore.telemetryKept));
    expect(rows.first.data, [1, 116, 0, 5]);
    expect(await store.lastTelemetryAt(key, 'n'), isNotNull);

    await store.clearTelemetry(key, 'n');
    expect(await store.watchTelemetry(key, 'n').first, isEmpty);
    expect(await store.lastTelemetryAt(key, 'n'), isNull);
  });

  test('upgrading from version 6 adds the telemetry history', () async {
    final dir = await Directory.systemTemp.createTemp('notoryx_db');
    final file = File('${dir.path}/v6.sqlite');
    var db6 = MeshDatabase(NativeDatabase(file));
    final self = decodeFrame(selfInfoFrame()) as SelfInfo;
    await MeshStore(db6).rememberRadio(self);
    await rollBackTo(db6, 6);
    await db6.close();

    db6 = MeshDatabase(NativeDatabase(file));
    final upgraded = MeshStore(db6);
    final k = self.publicKey.hex;
    expect(await upgraded.watchTelemetry(k, k).first, isEmpty);
    await upgraded.saveTelemetry(k, k, [1, 116, 0x01, 0x9A]);
    expect(await upgraded.watchTelemetry(k, k).first, hasLength(1));
    await db6.close();
    await dir.delete(recursive: true);
  });
}
