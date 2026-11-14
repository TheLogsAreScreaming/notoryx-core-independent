import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/node_journal.dart';
import 'package:notoryx_core/app/safety.dart';
import 'package:notoryx_core/app/timeline.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/screens/timeline_screen.dart';

final now = DateTime(2026, 11, 13, 12);
final _ridge = 'cd' * 32;

Message _msg(
  int id,
  String body, {
  required DateTime at,
  bool outgoing = false,
  String thread = 'c:0',
  String? sender = 'Ana',
}) => Message(
  id: id,
  radioKey: 'r',
  kind: MessageKind.channel,
  thread: thread,
  outgoing: outgoing,
  body: body,
  senderName: sender,
  sentAt: at.millisecondsSinceEpoch ~/ 1000,
  storedAt: at.millisecondsSinceEpoch,
  status: outgoing ? MessageStatus.sent : MessageStatus.received,
  attempts: 0,
  textType: 0,
);

JournalNode _node(String key, String name, DateTime first) => JournalNode(
  radioKey: 'r',
  nodeKey: key,
  name: name,
  type: 2,
  firstHeard: first.millisecondsSinceEpoch,
  lastHeard: now.millisecondsSinceEpoch,
  heardCount: 5,
  tags: '',
  note: '',
);

JournalSighting _seen(
  String key,
  DateTime at, {
  double? snr,
  double? lat,
  double? lon,
}) => JournalSighting(
  id: at.millisecondsSinceEpoch,
  radioKey: 'r',
  nodeKey: key,
  at: at.millisecondsSinceEpoch,
  snr: snr,
  latitude: lat,
  longitude: lon,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final since = now.subtract(const Duration(days: 7));
  final old = now.subtract(const Duration(days: 20));
  final ridge = _node(_ridge, 'Ridge', old);
  final fresh = _node(
    'ef' * 32,
    'Fresh',
    now.subtract(const Duration(hours: 3)),
  );

  List<TimelineEvent> build() => buildTimeline(
    messages: [
      _msg(1, 'Hello', at: now.subtract(const Duration(hours: 1))),
      _msg(
        2,
        '📍 35.22710,-80.84310',
        at: now.subtract(const Duration(hours: 2)),
        outgoing: true,
        sender: null,
      ),
      _msg(3, 'too old', at: old),
    ],
    chatTitles: {'c:0': 'Public'},
    nodes: [ridge, fresh],
    sightings: {
      _ridge: [
        _seen(_ridge, old, snr: 8, lat: 35.0, lon: -80.0),
        _seen(_ridge, now.subtract(const Duration(days: 3)), snr: 9),
        _seen(_ridge, now.subtract(const Duration(days: 2)), snr: 8.5),
        // 9 dB weaker than the average: a signal change.
        _seen(
          _ridge,
          now.subtract(const Duration(days: 1)),
          snr: -0.5,
          lat: 35.0,
          lon: -80.0,
        ),
        // Moved about 11 km: a new place.
        _seen(
          _ridge,
          now.subtract(const Duration(hours: 5)),
          lat: 35.1,
          lon: -80.0,
        ),
      ],
    },
    since: since,
  );

  test('one feed, newest first, of every kind', () {
    final events = build();
    expect(events.map((e) => e.kind), [
      TimelineKind.message, // Hello, 1 h ago
      TimelineKind.position, // shared, 2 h ago
      TimelineKind.message, // the shared position message
      TimelineKind.newNode, // Fresh, 3 h ago
      TimelineKind.position, // Ridge moved, 5 h ago
      TimelineKind.signal, // Ridge weaker, 1 d ago
    ]);
    for (var i = 1; i < events.length; i++) {
      expect(events[i - 1].at.isBefore(events[i].at), isFalse);
    }
  });

  test('a signal change compares against the recent average', () {
    final signal = build().whereType<SignalEvent>().single;
    expect(signal.name, 'Ridge');
    expect(signal.from, closeTo(8.5, 0.01));
    expect(signal.to, -0.5);
    expect(signal.better, isFalse);
  });

  test('an old node doesn’t show as new, nor its first place', () {
    final events = build();
    expect(events.whereType<NewNodeEvent>().map((e) => e.name), ['Fresh']);
    expect(
      events.whereType<PositionEvent>().where((e) => e.nodeKey == _ridge),
      hasLength(1),
    );
  });

  test('filters by kind and text', () {
    final events = build();
    expect(filterTimeline(events, {TimelineKind.message}), hasLength(2));
    expect(
      filterTimeline(events, {...TimelineKind.values}, query: 'ridge'),
      hasLength(2),
    );
    expect(
      filterTimeline(events, {TimelineKind.message}, query: 'hello'),
      hasLength(1),
    );
  });

  testWidgets('the screen lists events with words and filters them', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final db = MeshDatabase.inMemory();
    final store = MeshStore(db);
    await tester.runAsync(() async {
      await db
          .into(db.radios)
          .insert(
            RadiosCompanion.insert(
              publicKey: 'r',
              name: 'Base',
              lastConnectedAt: 0,
            ),
          );
      await recordSighting(
        db,
        'r',
        nodeKey: _ridge,
        at: now.subtract(const Duration(hours: 2)),
        name: 'Ridge',
        type: 2,
        snr: 5,
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          storeProvider.overrideWithValue(store),
          radioKeyProvider.overrideWithValue('r'),
          safetyClockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: TimelineScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(find.text('Ridge heard for the first time'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'New nodes'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'New nodes'));
    await tester.pump();
    expect(find.text('Ridge heard for the first time'), findsNothing);
    expect(find.text('Nothing matches the filters.'), findsOneWidget);
    expect(find.byTooltip('Refresh timeline'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });
}
