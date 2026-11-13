import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/repeater_test.dart';
import 'package:notoryx_core/app/safety.dart';
import 'package:notoryx_core/app/wardrive.dart';
import 'package:notoryx_core/data/data.dart' hide WardriveHit;

String key(String start) => start.padRight(64, '0');

WardriveHit hit(String k, double heardUs, double weHeard, {int rssi = -90}) =>
    (publicKey: key(k), heardUs: heardUs, weHeard: weHeard, rssi: rssi);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('signal rates by the weaker direction', () {
    expect(ResponderSignal.fromSnr(2), ResponderSignal.strong);
    expect(ResponderSignal.fromSnr(-6), ResponderSignal.usable);
    expect(ResponderSignal.fromSnr(-11), ResponderSignal.weak);
    final r = responders([hit('aa', 8, -12)]).single;
    expect(r.weakerSnr, -12);
    expect(r.signal, ResponderSignal.weak);
  });

  test('responders are named from contacts, then adverts, best first', () {
    final list = responders(
      [hit('aa', -8, -9), hit('bb', 4, 6), hit('cc', 1, -2)],
      contacts: [
        Contact(
          radioKey: 'r',
          publicKey: key('bb'),
          name: 'Ridge',
          type: 2,
          flags: 0,
          outPathLength: 0,
          outPath: Uint8List(64),
          lastAdvert: 0,
          lastModified: 0,
        ),
      ],
      discovered: [
        DiscoveredData(
          radioKey: 'r',
          publicKey: key('CC').toUpperCase(),
          name: 'Barn',
          type: 2,
          lastAdvert: 0,
          heardAt: 0,
        ),
      ],
    );
    expect([for (final r in list) r.name], ['Ridge', 'Barn', null]);
    expect([for (final r in list) r.isContact], [true, false, false]);
  });

  group('the test', () {
    late ProviderContainer container;
    RepeaterProbe? probe;

    setUp(() {
      final db = MeshDatabase.inMemory();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repeaterProbeProvider.overrideWith((ref) => probe),
          safetyClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 13, 9, 30),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
    });

    test('collects answers', () async {
      probe = () async => [hit('aa', 1, 2)];
      final test = container.read(repeaterTestProvider.notifier);
      final run = test.run();
      expect(container.read(repeaterTestProvider), isA<RepeaterTestRunning>());
      await run;
      final done = container.read(repeaterTestProvider) as RepeaterTestDone;
      expect(done.hits, hasLength(1));
      expect(done.at, DateTime(2026, 11, 13, 9, 30));
    });

    test('says when the radio could not send it', () async {
      probe = () async => throw StateError('radio gone');
      await container.read(repeaterTestProvider.notifier).run();
      expect(container.read(repeaterTestProvider), isA<RepeaterTestFailed>());
    });

    test('does nothing without a radio', () async {
      probe = null;
      await container.read(repeaterTestProvider.notifier).run();
      expect(container.read(repeaterTestProvider), isA<RepeaterTestIdle>());
    });
  });
}
