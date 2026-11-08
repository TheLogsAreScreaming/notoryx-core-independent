import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:flutter/services.dart';
import 'package:notoryx_core/app/about.dart';
import 'package:notoryx_core/app/notifications.dart';
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> start(WidgetTester tester) async {
    db = MeshDatabase.inMemory();
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
          messageNotifierProvider.overrideWithValue(FakeNotifier()),
          foregroundCheckProvider.overrideWithValue(() => true),
          appVersionProvider.overrideWith(
            (ref) async => (
              name: 'NOTORYX Independent',
              version: '0.1.0-test.16',
              build: '16',
            ),
          ),
          platformDescriptionProvider.overrideWithValue('android 14'),
        ],
        child: const NotoryxApp(),
      ),
    );
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

  testWidgets('About shows the version and copies report details', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await start(tester);

    // Before connecting: from the connect screen.
    await tester.tap(find.byTooltip('About'));
    await settle(tester);
    expect(find.text('Version 0.1.0-test.16 (build 16)'), findsOneWidget);
    expect(find.textContaining('Radio: not connected'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    // Connected: from radio settings, with the radio's details.
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
    await tester.tap(find.byTooltip('Radio settings'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('About this app'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await settle(tester);
    await tester.tap(find.text('About this app'));
    await settle(tester);
    await tester.tap(find.text('Copy details'));
    await settle(tester);
    expect(
      copied,
      contains('App: NOTORYX Independent 0.1.0-test.16 (build 16)'),
    );
    expect(copied, contains('Device: android 14'));
    expect(copied, contains('Firmware: v1.18.0 (protocol 14)'));
    expect(copied, contains('Connected over: Bluetooth'));
    expect(find.text('Details copied'), findsOneWidget);
    await cleanUp(tester);
  });
}
