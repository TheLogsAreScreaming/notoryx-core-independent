import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/radio_stats.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/schema_rollback.dart';
import '../support/scripted_radio.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late ScriptedRadio radio;
  late MeshDatabase db;
  late MeshStore store;
  late MeshSync sync;
  late String key;

  setUp(() async {
    final link = FakeRadioLink();
    radio = ScriptedRadio(link);
    db = MeshDatabase.inMemory();
    store = MeshStore(db);
    sync = MeshSync(RadioSession(link), store);
    key = (await sync.start(now: DateTime.utc(2026, 11, 7))).key;
  });

  tearDown(() async {
    await sync.stop();
    await db.close();
  });

  test('the stats frame decodes', () {
    final frame = decodeFrame([
      ResponseCode.stats,
      StatsGroup.radio,
      0x8E, 0xFF, // -114
      0xB0, // -80
      0xE8, // -24 → -6 dB
      ...u32(75),
      ...u32(3600),
    ]);
    expect(frame, isA<RadioStats>());
    final stats = frame as RadioStats;
    expect(stats.noiseFloor, -114);
    expect(stats.lastRssi, -80);
    expect(stats.lastSnr, -6);
    expect(stats.txAirSeconds, 75);
    expect(stats.rxAirSeconds, 3600);
    expect(decodeFrame([ResponseCode.stats, 0, 1, 2]), isA<OtherStats>());
  });

  test('a sample is read and stored', () async {
    final stats = await sync.sampleRadioStats();
    expect(stats!.noiseFloor, -112);
    final rows = await store.watchRadioStats(key).first;
    expect(rows.single.noiseFloor, -112);
    expect(rows.single.lastSnr, 6);
    expect(rows.single.rxAirSeconds, 600);
  });

  test('firmware without stats gives null and stores nothing', () async {
    radio.noiseFloor = null;
    expect(await sync.sampleRadioStats(), isNull);
    expect(await store.watchRadioStats(key).first, isEmpty);
  });

  test('history keeps the newest samples only', () async {
    for (var i = 0; i < MeshStore.radioStatsKept + 3; i++) {
      await store.saveRadioStats(
        key,
        RadioStats(
          noiseFloor: -i,
          lastRssi: 0,
          lastSnr: 0,
          txAirSeconds: 0,
          rxAirSeconds: 0,
        ),
      );
    }
    final rows = await store.watchRadioStats(key).first;
    expect(rows, hasLength(MeshStore.radioStatsKept));
    expect(rows.first.noiseFloor, -3);
    await store.clearRadioStats(key);
    expect(await store.lastRadioStatsAt(key), isNull);
  });

  test('plain words for the figures', () {
    expect(noiseVerdict(-120), startsWith('Quiet'));
    expect(noiseVerdict(-108), 'Normal.');
    expect(noiseVerdict(-100), startsWith('Noisy'));
    expect(noiseVerdict(-80), startsWith('Very noisy'));
    expect(formatAirtime(42), '42 s');
    expect(formatAirtime(125), '2 min 5 s');
    expect(formatAirtime(7500), '2 h 5 min');
    expect(RadioStatsSeries.lastSnr.format(6.25), '6.3 dB');
  });

  test('upgrading from version 7 adds the noise history', () async {
    final dir = await Directory.systemTemp.createTemp('notoryx_db');
    final file = File('${dir.path}/v7.sqlite');
    var old = MeshDatabase(NativeDatabase(file));
    final self = decodeFrame(selfInfoFrame()) as SelfInfo;
    await MeshStore(old).rememberRadio(self);
    await rollBackTo(old, 7);
    await old.close();

    old = MeshDatabase(NativeDatabase(file));
    final upgraded = MeshStore(old);
    final k = self.publicKey.hex;
    expect(await upgraded.watchRadioStats(k).first, isEmpty);
    await upgraded.saveRadioStats(
      k,
      const RadioStats(
        noiseFloor: -110,
        lastRssi: -90,
        lastSnr: 5,
        txAirSeconds: 1,
        rxAirSeconds: 2,
      ),
    );
    expect(await upgraded.watchRadioStats(k).first, hasLength(1));
    await old.close();
    await dir.delete(recursive: true);
  });
}
