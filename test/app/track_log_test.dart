import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/telemetry.dart';
import 'package:notoryx_core/app/track_log.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;
  late ProviderContainer container;
  late StreamController<TrackFix> fixes;

  setUp(() {
    db = MeshDatabase.inMemory();
    fixes = StreamController<TrackFix>();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        trackFixesProvider.overrideWithValue(() => fixes.stream),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('records fixes, then closes the track', () async {
    final recorder = container.read(trackRecorderProvider.notifier);
    await recorder.start('Walk');
    final id = container.read(trackRecorderProvider)!;
    fixes
      ..add((latitude: 35.0, longitude: -80.0, altitude: 200.0))
      ..add((latitude: 35.001, longitude: -80.0, altitude: null));
    await pumpEventQueue();
    await recorder.stop();

    final store = container.read(storeProvider);
    final points = await store.watchTrackPoints(id).first;
    expect(points, hasLength(2));
    expect(trackLengthMetres(points), closeTo(111, 2));
    final track = (await store.watchTracks().first).single;
    expect(track.endedAt, isNotNull);
    expect(container.read(trackRecorderProvider), isNull);
  });

  test('a refused location removes the empty track', () async {
    final refused = StreamController<TrackFix>();
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        trackFixesProvider.overrideWithValue(() => refused.stream),
      ],
    );
    addTearDown(c.dispose);
    refused.addError(const TrackLocationException());
    await expectLater(
      c.read(trackRecorderProvider.notifier).start('Walk'),
      throwsA(isA<TrackLocationException>()),
    );
    expect(await c.read(storeProvider).watchTracks().first, isEmpty);
    expect(c.read(trackRecorderProvider), isNull);
  });

  test('GPX is well formed and escapes the name', () {
    const track = Track(id: 1, name: 'A & B', startedAt: 0, endedAt: 1);
    const point = TrackPoint(
      id: 1,
      track: 1,
      at: 1000,
      latitude: 35.5,
      longitude: -80.25,
      altitude: 12.5,
    );
    final gpx = gpxFor(track, [point]);
    expect(gpx, contains('<name>A &amp; B</name>'));
    expect(gpx, contains('<trkpt lat="35.5" lon="-80.25">'));
    expect(gpx, contains('<ele>12.5</ele>'));
    expect(gpx, contains('<time>1970-01-01T00:00:01.000Z</time>'));
  });

  group('map badge', () {
    TelemetrySample sample(List<int> data, DateTime at) => TelemetrySample(
      id: 1,
      radioKey: 'r',
      nodeKey: 'n',
      at: at.millisecondsSinceEpoch,
      data: Uint8List.fromList(data),
    );
    final now = DateTime(2026, 11, 8, 12);

    test('shows battery and an outside sensor, not the chip', () {
      // Channel 1 voltage 3.90 V, channel 1 temp 40.0, channel 2 temp 18.5.
      final s = sample([1, 116, 1, 134, 1, 103, 1, 144, 2, 103, 0, 185], now);
      expect(telemetryBadge(s, now: now), '3.90 V · 18.5°C');
    });

    test('hides readings over a day old', () {
      final s = sample([
        1,
        116,
        1,
        134,
      ], now.subtract(const Duration(hours: 25)));
      expect(telemetryBadge(s, now: now), isNull);
    });
  });
}
