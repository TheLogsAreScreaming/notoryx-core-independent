import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/node_journal.dart';
import 'package:notoryx_core/app/safety.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/node_journal_screen.dart';

import '../support/schema_rollback.dart';

final _key = 'ab' * 32;

/// An advert payload as the MeshCore format lays it out.
Uint8List advert({
  required String key,
  int type = 2,
  double? lat,
  double? lon,
  String? name,
}) {
  final out = BytesBuilder()
    ..add(fromHex(key))
    ..add(
      (ByteData(
        4,
      )..setUint32(0, 1700000000, Endian.little)).buffer.asUint8List(),
    )
    ..add(List.filled(64, 7));
  var flags = type;
  if (lat != null) flags |= 0x10;
  if (name != null) flags |= 0x80;
  out.addByte(flags);
  if (lat != null) {
    out.add(
      (ByteData(8)
            ..setInt32(0, (lat * 1e6).round(), Endian.little)
            ..setInt32(4, (lon! * 1e6).round(), Endian.little))
          .buffer
          .asUint8List(),
    );
  }
  if (name != null) out.add(utf8.encode(name));
  return out.toBytes();
}

JournalNode _node({
  int type = 2,
  required DateTime first,
  required DateTime last,
  int count = 10,
}) => JournalNode(
  radioKey: 'r',
  nodeKey: _key,
  name: 'Tower',
  type: type,
  firstHeard: first.millisecondsSinceEpoch,
  lastHeard: last.millisecondsSinceEpoch,
  heardCount: count,
  tags: '',
  note: '',
);

List<JournalSighting> _every(
  Duration step,
  DateTime from,
  DateTime to, {
  (double, double) Function(int i)? at,
}) {
  final out = <JournalSighting>[];
  var i = 0;
  for (var t = from; !t.isAfter(to); t = t.add(step)) {
    final p = at?.call(i);
    out.add(
      JournalSighting(
        id: i,
        radioKey: 'r',
        nodeKey: _key,
        at: t.millisecondsSinceEpoch,
        snr: 5,
        hops: 1,
        latitude: p?.$1,
        longitude: p?.$2,
      ),
    );
    i++;
  }
  return out;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final now = DateTime(2026, 11, 13, 12);

  group('advert payloads', () {
    test('name, type and position are read', () {
      final a = parseAdvertPayload(
        advert(key: _key, type: 2, lat: 35.2271, lon: -80.8431, name: 'Hill'),
      )!;
      expect(a.publicKey, _key);
      expect(a.type, 2);
      expect(a.latitude, closeTo(35.2271, 1e-6));
      expect(a.longitude, closeTo(-80.8431, 1e-6));
      expect(a.name, 'Hill');
      expect(a.timestamp, 1700000000);
    });

    test('no position or name is fine; too short is null', () {
      final a = parseAdvertPayload(advert(key: _key, type: 1))!;
      expect(a.latitude, isNull);
      expect(a.name, isNull);
      expect(parseAdvertPayload(Uint8List(50)), isNull);
    });
  });

  group('recording', () {
    late MeshDatabase db;
    setUp(() => db = MeshDatabase.inMemory());
    tearDown(() => db.close());

    test(
      'first hearing adds the node; repeats close together count once',
      () async {
        await recordSighting(db, 'r', nodeKey: _key, at: now, name: 'Hill');
        await recordSighting(
          db,
          'r',
          nodeKey: _key,
          at: now.add(const Duration(seconds: 3)),
        );
        await recordSighting(
          db,
          'r',
          nodeKey: _key,
          at: now.add(const Duration(minutes: 5)),
          name: 'Hill 2',
          snr: -3,
        );
        final node = await db.select(db.journalNodes).getSingle();
        expect(node.heardCount, 2);
        expect(node.name, 'Hill 2');
        expect(node.firstHeard, now.millisecondsSinceEpoch);
        expect(await db.select(db.journalSightings).get(), hasLength(2));
      },
    );

    test('positions at 0,0 are dropped, old sightings trimmed', () async {
      for (var i = 0; i < journalSightingsPerNode + 5; i++) {
        await recordSighting(
          db,
          'r',
          nodeKey: _key,
          at: now.add(Duration(minutes: i)),
          latitude: 0,
          longitude: 0,
        );
      }
      final rows = await db.select(db.journalSightings).get();
      expect(rows, hasLength(journalSightingsPerNode));
      expect(rows.every((r) => r.latitude == null), isTrue);
      expect(
        rows.map((r) => r.at).reduce((a, b) => a < b ? a : b),
        now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
    });

    test('tags and notes are kept; forgetting removes everything', () async {
      await recordSighting(db, 'r', nodeKey: _key, at: now);
      await saveJournalNotes(
        db,
        'r',
        _key,
        tags: [' hill ', 'Hill', '', 'solar'],
        note: ' on the ridge ',
      );
      final node = await db.select(db.journalNodes).getSingle();
      expect(tagsOf(node), ['hill', 'solar']);
      expect(node.note, 'on the ridge');
      await forgetJournalNode(db, 'r', _key);
      expect(await db.select(db.journalNodes).get(), isEmpty);
      expect(await db.select(db.journalSightings).get(), isEmpty);
    });

    test('a version 14 database upgrades with an empty journal', () async {
      final dir = await Directory.systemTemp.createTemp('journal');
      final file = File('${dir.path}/v14.sqlite');
      final old = MeshDatabase(NativeDatabase(file));
      await recordSighting(old, 'r', nodeKey: _key, at: now);
      await rollBackTo(old, 14);
      await old.close();
      final upgraded = MeshDatabase(NativeDatabase(file));
      expect(await upgraded.select(upgraded.journalNodes).get(), isEmpty);
      await recordSighting(upgraded, 'r', nodeKey: _key, at: now);
      expect(await upgraded.select(upgraded.journalNodes).get(), hasLength(1));
      await upgraded.close();
      await dir.delete(recursive: true);
    });
  });

  group('labels', () {
    test('a repeater heard every two hours for ten days is always-on', () {
      final first = now.subtract(const Duration(days: 10));
      final labels = describeNode(
        _node(first: first, last: now, count: 120),
        _every(const Duration(hours: 2), first, now),
        now,
      );
      expect(labels.first.behaviour, NodeBehaviour.alwaysOn);
      expect(labels.first.confidence, greaterThan(0.8));
      expect(labels.first.evidence.whereType<HeardOnDays>().single.days, 11);
      expect(labels.first.evidence.whereType<TypicalGap>().single.hours, 2);
    });

    test('a person reporting places far apart is a roamer', () {
      final first = now.subtract(const Duration(days: 1));
      final labels = describeNode(
        _node(type: 1, first: first, last: now),
        _every(
          const Duration(hours: 3),
          first,
          now,
          at: (i) => (35 + i * 0.02, -80.0),
        ),
        now,
      );
      final roamer = labels.firstWhere(
        (l) => l.behaviour == NodeBehaviour.roamer,
      );
      expect(roamer.confidence, greaterThan(0.9));
      expect(roamer.evidence.single, isA<PositionSpread>());
    });

    test('three hearings in three weeks is rarely heard', () {
      final first = now.subtract(const Duration(days: 21));
      final labels = describeNode(
        _node(type: 1, first: first, last: first.add(const Duration(days: 9))),
        _every(
          const Duration(days: 4),
          first,
          first.add(const Duration(days: 9)),
        ),
        now,
      );
      expect(labels.first.behaviour, NodeBehaviour.rarelyHeard);
      expect(
        labels.first.evidence,
        contains(isA<LastHeardAgo>().having((e) => e.days, 'days', 12)),
      );
    });

    test('a node first heard an hour ago is new, at most 60% sure', () {
      final first = now.subtract(const Duration(hours: 1));
      final labels = describeNode(
        _node(type: 1, first: first, last: first, count: 1),
        _every(const Duration(hours: 1), first, first),
        now,
      );
      expect(labels.single.behaviour, NodeBehaviour.newArrival);
      expect(labels.single.confidence, lessThanOrEqualTo(0.6));
    });

    test('a busy node silent for two weeks has gone quiet', () {
      final first = now.subtract(const Duration(days: 40));
      final last = now.subtract(const Duration(days: 14));
      final labels = describeNode(
        _node(type: 1, first: first, last: last, count: 30),
        const [],
        now,
      );
      expect(labels.map((l) => l.behaviour), contains(NodeBehaviour.goneQuiet));
    });
  });

  group('marks', () {
    test('the same key always gives the same mirrored mark', () {
      final a = nodeMark(_key);
      final b = nodeMark(_key.toUpperCase());
      expect(a.cells, b.cells);
      expect(a.hue, b.hue);
      for (var row = 0; row < 5; row++) {
        for (var col = 0; col < 5; col++) {
          expect(a.cells[row * 5 + col], a.cells[row * 5 + 4 - col]);
        }
      }
      expect(a.cells, contains(true));
      expect(a.hue, inInclusiveRange(0, 360));
    });

    test('keys sharing a prefix still look different', () {
      final a = nodeMark('${'11' * 31}00');
      final b = nodeMark('${'11' * 31}01');
      expect(
        a.cells.toString() == b.cells.toString() && a.hue == b.hue,
        isFalse,
      );
    });
  });

  testWidgets('a node page shows labels, evidence and tags to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final db = MeshDatabase.inMemory();
    final first = now.subtract(const Duration(days: 10));
    for (final s in _every(const Duration(hours: 2), first, now)) {
      await tester.runAsync(
        () => recordSighting(
          db,
          'r',
          nodeKey: _key,
          at: DateTime.fromMillisecondsSinceEpoch(s.at),
          name: 'Tower',
          type: 2,
          snr: 4,
        ),
      );
    }
    await tester.runAsync(
      () => saveJournalNotes(db, 'r', _key, tags: ['ridge']),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          safetyClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          home: JournalNodeScreen(radioKey: 'r', nodeKey: _key),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(find.text('Always-on repeater'), findsOneWidget);
    expect(find.text('• Heard on 11 of the last 11 days'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Always-on repeater\s+\d+% sure')),
      findsWidgets,
    );
    expect(find.text('ridge'), findsOneWidget);
    expect(find.byTooltip('Remove tag ridge'), findsOneWidget);
    expect(find.byTooltip('Forget this node'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });
}
