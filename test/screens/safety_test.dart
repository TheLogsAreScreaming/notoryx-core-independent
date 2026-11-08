import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/position.dart';
import 'package:notoryx_core/app/safety.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_notifier.dart';
import '../support/fake_radio_link.dart';
import '../support/scripted_radio.dart';

class _Connector implements RadioConnector {
  _Connector(this.newLink);

  final FakeRadioLink Function() newLink;

  @override
  bool get supportsUsb => false;

  @override
  Stream<BleTarget> scanBluetooth({bool all = false}) => Stream.value(
    const BleTarget(deviceId: 'aa', label: 'MeshCore-Base', rssi: -60),
  );

  @override
  Future<List<UsbTarget>> listUsb() async => const [];

  @override
  Future<RadioLink> open(RadioTarget target) async => newLink();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;
  late FakeNotifier notifier;
  var now = DateTime(2026, 11, 7, 9);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<List<String>> sent(WidgetTester tester) async =>
      (await tester.runAsync(
        () => (db.select(
          db.messages,
        )..where((m) => m.outgoing.equals(true))).map((m) => m.body).get(),
      ))!;

  Future<void> openSafety(WidgetTester tester) async {
    db = MeshDatabase.inMemory();
    notifier = FakeNotifier();
    now = DateTime(2026, 11, 7, 9);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          radioConnectorProvider.overrideWithValue(
            _Connector(() {
              final link = FakeRadioLink();
              ScriptedRadio(link);
              return link;
            }),
          ),
          messageNotifierProvider.overrideWithValue(notifier),
          foregroundCheckProvider.overrideWithValue(() => true),
          phonePositionProvider.overrideWithValue(
            () async => const LatLng(46.5, -121.25),
          ),
          safetyClockProvider.overrideWithValue(() => now),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
    await tester.tap(find.byTooltip('Safety: SOS and check-ins'));
    await settle(tester);
    await tester.tap(find.text('Send to'));
    await settle(tester);
    await tester.tap(find.text('#trail').last);
    await settle(tester);
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('SOS asks first, then sends with the position', (tester) async {
    await openSafety(tester);
    await tester.tap(find.text('Send SOS'));
    await settle(tester);
    expect(find.text('Send SOS?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await sent(tester), isEmpty);

    await tester.tap(find.text('Send SOS'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Send SOS').last);
    await settle(tester);
    expect(await sent(tester), [
      'SOS - I need help. Position 46.50000,-121.25000',
    ]);
    expect(find.text('SOS sent to #trail.'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a missed check-in reminds, then tells the chat', (tester) async {
    await openSafety(tester);
    await tester.tap(find.text('Check in every'));
    await settle(tester);
    await tester.tap(find.text('30 minutes').last);
    await settle(tester);
    expect(find.textContaining('Next check-in due'), findsOneWidget);

    // Checking in on time pushes the deadline back.
    now = now.add(const Duration(minutes: 20));
    await tester.tap(find.text("I'm OK"));
    await settle(tester);
    expect(await sent(tester), [
      "Check-in: I'm OK. Position 46.50000,-121.25000",
    ]);
    now = now.add(const Duration(minutes: 20));
    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
    expect(notifier.shown, isEmpty);

    now = now.add(const Duration(minutes: 11));
    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
    expect(notifier.shown.single.title, 'Check-in due');

    now = now.add(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
    final bodies = await sent(tester);
    expect(bodies, hasLength(2));
    expect(bodies.last, startsWith('Missed check-in (due 09:50).'));
    expect(find.textContaining('Next check-in due'), findsNothing);

    // Sent once only.
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);
    expect(await sent(tester), hasLength(2));
    await cleanUp(tester);
  });

  test('message texts', () {
    expect(sosText(null), 'SOS - I need help. Position unknown.');
    expect(
      missedText(null, due: DateTime(2026, 1, 1, 7, 5)),
      'Missed check-in (due 07:05). No reply from me. Last known position unknown.',
    );
  });
}
