import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection_log.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('the log splits into Bluetooth and app entries', () {
    const ble = '2026-11-08T09:30:00  BLE MTU 185';
    const app = '2026-11-08T09:30:01  connect tapped: Hilltop';
    expect(entriesFor([ble, app], LogView.all), [ble, app]);
    expect(entriesFor([ble, app], LogView.bluetooth), [ble]);
    expect(entriesFor([ble, app], LogView.app), [app]);
  });

  test('entries are timestamped, kept across restarts and capped', () async {
    final db = MeshDatabase.inMemory();
    final store = MeshStore(db);
    var now = DateTime(2026, 11, 6, 9, 30);
    final first = ConnectionLog(store, clock: () => now);
    await first.load();
    first.add('app started');
    for (var i = 0; i < ConnectionLog.maxEntries + 5; i++) {
      now = now.add(const Duration(seconds: 1));
      first.add('event $i');
    }
    expect(first.entries, hasLength(ConnectionLog.maxEntries));
    expect(
      first.entries.last,
      endsWith('event ${ConnectionLog.maxEntries + 4}'),
    );
    await first.dispose(); // writes what's pending

    final second = ConnectionLog(store);
    await second.load();
    expect(second.entries, hasLength(ConnectionLog.maxEntries));
    expect(second.entries.first, startsWith('2026-11-06T09:'));

    await second.clear();
    expect(await store.setting(ConnectionLog.setting), isNull);
    await second.dispose();
    await db.close();
  });
}
