import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/telemetry_alerts.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('only a step across a limit alerts, then it stays quiet', () {
    final judge = LimitJudge();
    const limit = (above: 30.0, below: 0.0);
    final t = DateTime(2026, 11, 22, 12);
    expect(judge.judge('n', 25, limit, t), isNull);
    expect(judge.judge('n', 31, limit, t), isTrue);
    expect(judge.judge('n', 33, limit, t), isNull);
    expect(judge.judge('n', 20, limit, t), isNull);
    expect(
      judge.judge('n', -1, limit, t.add(const Duration(minutes: 5))),
      isNull,
    );
    expect(judge.judge('n', 10, limit, t), isNull);
    expect(
      judge.judge('n', -2, limit, t.add(const Duration(minutes: 40))),
      isFalse,
    );
    expect(outsideLimit((above: null, below: null), 5), isNull);
  });

  test('limits are saved per node and value, and removed', () async {
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(MeshStore(db))],
    );
    addTearDown(c.dispose);
    final store = c.read(storeProvider);
    final id = limitId(2, LppKind.temperature);
    await saveTelemetryLimit(
      store,
      radioKey: 'r',
      nodeKey: 'aa',
      id: id,
      limit: (above: 30, below: null),
    );
    const key = (radioKey: 'r', nodeKey: 'aa');
    final sub = c.listen(telemetryLimitsProvider(key), (_, _) {});
    addTearDown(sub.close);
    final limits = await c.read(telemetryLimitsProvider(key).future);
    expect(limits[id]?.above, 30);
    expect(limits[id]?.below, isNull);

    await saveTelemetryLimit(
      store,
      radioKey: 'r',
      nodeKey: 'aa',
      id: id,
      limit: null,
    );
    expect(
      await store.watchSettingsWithPrefix('telemetry_alert_v1:r:aa:').first,
      isEmpty,
    );
  });
}
