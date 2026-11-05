import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/scripted_radio.dart';

class _FakeConnector implements RadioConnector {
  _FakeConnector(this.link);

  final FakeRadioLink link;
  bool failOpen = false;

  @override
  bool get supportsUsb => false;

  bool? lastScanAll;

  @override
  Stream<BleTarget> scanBluetooth({bool all = false}) {
    lastScanAll = all;
    return Stream.fromIterable([
      const BleTarget(deviceId: 'aa', label: 'MeshCore-Base', rssi: -60),
      if (all)
        const BleTarget(
          deviceId: 'bb',
          label: 'Headphones',
          rssi: -40,
          isMeshCore: false,
        ),
    ]);
  }

  @override
  Future<List<UsbTarget>> listUsb() async => const [];

  @override
  Future<RadioLink> open(RadioTarget target) async {
    if (failOpen) throw const LinkClosedException('radio out of range');
    return link;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeRadioLink link;
  late ScriptedRadio radio;
  late _FakeConnector connector;
  late MeshDatabase db;

  setUp(() {
    link = FakeRadioLink();
    radio = ScriptedRadio(link);
    connector = _FakeConnector(link);
    db = MeshDatabase.inMemory();
  });

  // Database and fake-radio work runs on real async, outside the test's fake
  // clock, so alternate real waits with frames. Spinners never settle, so
  // this pumps a fixed number of times instead of pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          radioConnectorProvider.overrideWithValue(connector),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> connect(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
  }

  // Unmounting tears the connection down; let that finish on both clocks
  // before closing the database, or the close waits on work that can't run.
  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('connect over Bluetooth, open a channel and send', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Connect a radio'), findsOneWidget);
    expect(find.text('MeshCore-Base'), findsOneWidget);

    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
    expect(
      find.text('Base'),
      findsOneWidget,
      reason: 'radio name in the app bar',
    );
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('#trail'), findsOneWidget);

    await tester.tap(find.text('#trail'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'heading down');
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);

    expect(find.text('heading down'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'sent tick');
    expect(link.sent.last[0], CommandCode.sendChannelText);
    await cleanUp(tester);
  });

  testWidgets('show all lists other devices after MeshCore radios', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Headphones'), findsNothing);
    await tester.tap(find.text('Show all Bluetooth devices'));
    await settle(tester);
    expect(connector.lastScanAll, isTrue);
    final radio = tester.getTopLeft(find.text('MeshCore-Base')).dy;
    final other = tester.getTopLeft(find.text('Headphones')).dy;
    expect(
      radio,
      lessThan(other),
      reason: 'radios first despite weaker signal',
    );
    await cleanUp(tester);
  });

  testWidgets('contacts tab lists the radio contacts and opens a chat', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Person · no route yet'), findsOneWidget);

    await tester.tap(find.text('Alice'));
    await settle(tester);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Alice'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a failed connection shows why and stays on the connect screen', (
    tester,
  ) async {
    connector.failOpen = true;
    await connect(tester);
    expect(
      find.text('The connection closed before setup finished.'),
      findsOneWidget,
    );
    expect(find.text('Connect a radio'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('the radio dropping returns to the connect screen', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.text('Public'));
    await settle(tester);

    link.drop();
    await settle(tester);
    expect(find.text('Connect a radio'), findsOneWidget);
    expect(find.text('The radio disconnected.'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a message arriving shows in the chat list', (tester) async {
    await connect(tester);
    radio.queue.add(channelMessageFrame('Ridge: summit at noon'));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);

    expect(find.text('Ridge: summit at noon'), findsOneWidget);
    await cleanUp(tester);
  });
}
