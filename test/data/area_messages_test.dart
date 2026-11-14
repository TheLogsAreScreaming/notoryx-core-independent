import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/area_messages.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/area_messages_screen.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/scripted_radio.dart';

const _here = [AreaCircle(latitude: 47.6, longitude: -122.3)];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('sending', () {
    late FakeRadioLink link;
    late ScriptedRadio radio;
    late MeshDatabase db;
    late MeshStore store;
    late MeshSync sync;
    final now = DateTime.utc(2026, 11, 13);

    setUp(() {
      link = FakeRadioLink();
      radio = ScriptedRadio(link);
      db = MeshDatabase.inMemory();
      store = MeshStore(db);
      sync = MeshSync(
        RadioSession(link),
        store,
        contactRefreshDelay: Duration.zero,
      );
    });

    tearDown(() async {
      await sync.stop();
      await db.close();
    });

    List<int> commands() => [for (final f in link.sent) f[0]];

    test(
      'stock firmware: detected, and an area post goes out normally',
      () async {
        final key = (await sync.start(now: now)).key;
        expect(await sync.areaSupport(), AreaSupport.unsupported);

        link.sent.clear();
        await sync.sendChannel(1, 'trail closed', now: now, area: _here);
        expect(commands(), [
          CommandCode.sendChannelTextInArea, // tried once…
          CommandCode.sendChannelText, // …then sent normally
        ]);
        final message =
            (await store.watchThread(key, Threads.channel(1)).first).single;
        expect(message.status, MessageStatus.sent);
        expect(message.body, 'trail closed');
      },
    );

    test('flood-corridor firmware: the post carries the circle', () async {
      radio.areaLimits = true;
      final key = (await sync.start(now: now)).key;
      expect(await sync.areaSupport(), AreaSupport.supported);

      link.sent.clear();
      await sync.sendChannel(1, 'trail closed', now: now, area: _here);
      expect(commands(), [CommandCode.sendChannelTextInArea]);
      final frame = link.sent.single;
      expect(frame[frame.length - 2], 1); // one circle
      final message =
          (await store.watchThread(key, Threads.channel(1)).first).single;
      expect(message.status, MessageStatus.sent);
    });

    test('without an area nothing new is sent', () async {
      radio.areaLimits = true;
      await sync.start(now: now);
      link.sent.clear();
      await sync.sendChannel(1, 'hello', now: now);
      expect(commands(), [CommandCode.sendChannelText]);
    });

    test('a post too long with its circle is refused before storing', () async {
      final key = (await sync.start(now: now)).key;
      expect(
        () => sync.sendChannel(0, 'x' * 300, now: now, area: _here),
        throwsArgumentError,
      );
      await pumpEventQueue();
      expect(await store.watchThread(key, Threads.channel(0)).first, isEmpty);
    });
  });

  group('the setting', () {
    test('off by default, 50 km, bad values ignored', () {
      const s = AreaMessages();
      expect(s.on, isFalse);
      expect(s.radiusKm, 50);
      final read = AreaMessages.fromJson({'on': true, 'radius': 99});
      expect(read.on, isTrue);
      expect(read.radiusCode, defaultAreaRadiusCode);
      expect(AreaMessages.fromJson('junk').on, isFalse);
    });

    test('the circle needs the radio to have a position', () {
      SelfInfo self({double? lat, double? lon}) =>
          decodeFrame(selfInfoFrame(latitude: lat, longitude: lon)) as SelfInfo;
      expect(areaAround(self(), 8), isNull);
      expect(areaAround(self(lat: 0, lon: 0), 8), isNull);
      final circle = areaAround(self(lat: 47.6, lon: -122.3), 3)!.single;
      expect(circle.latitude, 47.6);
      expect(circle.radiusKm, 5);
    });

    test('kept across restarts', () async {
      final db = MeshDatabase.inMemory();
      addTearDown(db.close);
      ProviderContainer open() => ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final first = open();
      first.read(areaMessagesProvider);
      await first.read(areaMessagesProvider.notifier).setOn(true);
      await first.read(areaMessagesProvider.notifier).setRadius(5);
      first.dispose();
      final again = open();
      addTearDown(again.dispose);
      again.read(areaMessagesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(again.read(areaMessagesProvider).on, isTrue);
      expect(again.read(areaMessagesProvider).radiusCode, 5);
    });
  });

  testWidgets('the settings page explains, then shows what the radio can do', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final db = MeshDatabase.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          areaSupportProvider.overrideWith(
            (ref) async => AreaSupport.unsupported,
          ),
        ],
        child: const MaterialApp(home: AreaMessagesScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(
      find.textContaining('feature/flood-corridor branch'),
      findsOneWidget,
    );
    expect(
      find.text('Turn the option on to check the connected radio.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('area-on')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(
      find.bySemanticsLabel(
        RegExp(
          dotAll: true,
          "This radio's firmware.*Standard firmware: no area limits",
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('50 km around your radio'), findsOneWidget);
    await tester.tap(find.byTooltip('Smaller circle'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('30 km around your radio'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });
}
