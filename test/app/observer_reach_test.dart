import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/observer_reach.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/l10n/l10n.dart';
import 'package:notoryx_core/screens/observer_reach_screen.dart';

final _me = 'ab' * 32;
final _hill = 'c1' * 32;
final _tower = 'd2' * 32;
final _ridge = 'e3' * 32;

/// Shaped like the server's reply, with made-up stations.
Map<String, Object?> _reply() => {
  'node': {'pubkey': _me, 'name': 'Base', 'role': 'companion'},
  'window': {'days': 7, 'since': '2026-11-06T00:00:00Z'},
  'importance': {'direct_observers': 2},
  'direct_observers': [
    {
      'pubkey': _hill,
      'name': 'Hill listener',
      'count': 3,
      'avg_snr': -4.25,
      'distance_km': 12.4,
    },
    {'pubkey': _tower, 'name': '', 'count': 9},
    {'pubkey': '', 'count': 4},
    {'name': 'no key', 'count': 4},
    'junk',
  ],
  'links': [
    {
      'pubkey': _ridge,
      'name': 'Ridge',
      'we_hear': 40,
      'they_hear': 2,
      'bidir': false,
      'distance_km': 3.25,
    },
    {
      'pubkey': _hill,
      'name': 'Hill',
      'we_hear': 10,
      'they_hear': 12,
      'bidir': true,
    },
  ],
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('reading a reply', () {
    test('observers most packets first; unnamed shown by short key', () {
      final reach = ObserverReach.fromJson(_reply())!;
      expect(reach.days, 7);
      expect(reach.observers.map((o) => o.name), ['D2D2D2D2', 'Hill listener']);
      final hill = reach.observers.last;
      expect(hill.count, 3);
      expect(hill.snr, -4.25);
      expect(hill.km, 12.4);
      expect(reach.observers.first.snr, isNull);
    });

    test('links strongest both-way count first', () {
      final reach = ObserverReach.fromJson(_reply())!;
      expect(reach.links.map((l) => l.name), ['Hill', 'Ridge']);
      expect(reach.links.last.both, isFalse);
      expect(reach.links.last.weHear, 40);
    });

    test('anything else is not a reply', () {
      expect(ObserverReach.fromJson(null), isNull);
      expect(ObserverReach.fromJson(const ['x']), isNull);
      expect(ObserverReach.fromJson(const {'error': 'Not found'}), isNull);
      final bare = ObserverReach.fromJson({'node': <String, Object?>{}})!;
      expect(bare.observers, isEmpty);
      expect(bare.links, isEmpty);
      expect(bare.days, 7);
    });

    test('the address asks for the lower-case key', () {
      final uri = reachUri('https://an.example.org', _me.toUpperCase());
      expect(uri.toString(), 'https://an.example.org/api/nodes/$_me/reach');
    });
  });

  group('settings', () {
    test('off by default, with the public server', () {
      const s = ReachSettings();
      expect(s.on, isFalse);
      expect(s.server, defaultReachServer);
      expect(ReachSettings.fromJson(null).on, isFalse);
    });

    test('a stored plain-http server falls back to the default', () {
      final s = ReachSettings.fromJson({
        'on': true,
        'server': 'http://plain.example.org',
      });
      expect(s.on, isTrue);
      expect(s.server, defaultReachServer);
    });
  });

  group('checking', () {
    late MeshDatabase db;
    late List<Uri> asked;
    late ({int status, Object? body}) Function() answer;
    late ProviderContainer container;

    setUp(() {
      db = MeshDatabase.inMemory();
      asked = [];
      answer = () => (status: 200, body: _reply());
      ReachNotifier.fetch = (uri) async {
        asked.add(uri);
        return answer();
      };
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      container.read(observerReachProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    ReachNotifier notifier() => container.read(observerReachProvider.notifier);

    test('while off, nothing is sent', () async {
      expect(await notifier().check(_me), isA<ReachOff>());
      expect(asked, isEmpty);
    });

    test('once on, the key goes to the chosen server', () async {
      await notifier().setOn(true);
      expect(await notifier().setServer(' https://mine.example.org '), isTrue);
      final result = await notifier().check(_me);
      expect(result, isA<ReachFound>());
      expect((result as ReachFound).reach.observers, hasLength(2));
      expect(asked.single.host, 'mine.example.org');
      expect(asked.single.path, '/api/nodes/$_me/reach');
    });

    test('an http server is refused and the old one kept', () async {
      expect(await notifier().setServer('http://plain.example.org'), isFalse);
      expect(container.read(observerReachProvider).server, defaultReachServer);
    });

    test('unknown, failing and malformed answers', () async {
      await notifier().setOn(true);
      answer = () => (status: 404, body: const {'error': 'Not found'});
      expect(await notifier().check(_me), isA<ReachUnknown>());
      answer = () => (status: 500, body: null);
      expect(await notifier().check(_me), isA<ReachFailed>());
      answer = () => (status: 200, body: 'nope');
      expect(await notifier().check(_me), isA<ReachFailed>());
      answer = () => throw const SocketExceptionStandIn();
      expect(await notifier().check(_me), isA<ReachFailed>());
    });

    test('a key that is not 64 hex digits is never sent', () async {
      await notifier().setOn(true);
      expect(await notifier().check('../../admin'), isA<ReachFailed>());
      expect(asked, isEmpty);
    });

    test('the choice survives a restart', () async {
      await notifier().setOn(true);
      await notifier().setServer('https://mine.example.org');
      final again = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(again.dispose);
      again.read(observerReachProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final s = again.read(observerReachProvider);
      expect(s.on, isTrue);
      expect(s.server, 'https://mine.example.org');
    });
  });

  testWidgets('the screen says what is sent, then lists who heard it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final db = MeshDatabase.inMemory();
    final asked = <Uri>[];
    ReachNotifier.fetch = (uri) async {
      asked.add(uri);
      return (status: 200, body: _reply());
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ObserverReachScreen(nodeKey: _me, name: 'Base'),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    expect(
      find.textContaining('analyzer.on8ar.eu which observers'),
      findsOneWidget,
    );
    expect(
      find.text('Off. Nothing is sent until you turn this on.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reach-check')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reach-on')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(asked, isEmpty);
    expect(
      find.text(
        "On. Sends this radio's public key to analyzer.on8ar.eu when you check.",
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('reach-check')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(asked, hasLength(1));
    expect(
      find.text('Heard directly by 2 observers in the last 7 days'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('reach-summary'))),
      matchesSemantics(
        label: 'Heard directly by 2 observers in the last 7 days',
        isHeader: true,
        isLiveRegion: true,
      ),
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          dotAll: true,
          'Hill listener.*3 packets · average SNR -4.3 dB · 12 km away',
        ),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('reach-link-$_ridge')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          dotAll: true,
          'Ridge.*It heard them 40 times, they heard it 2 times · '
          'one way only · 3.3 km away',
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });
}

/// A network failure, without depending on dart:io in the test.
class SocketExceptionStandIn implements Exception {
  const SocketExceptionStandIn();
}
