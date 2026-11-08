import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
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

  late ScriptedRadio radio;
  late MeshDatabase db;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openSettings(WidgetTester tester) async {
    db = MeshDatabase.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          radioConnectorProvider.overrideWithValue(
            _Connector(() {
              final link = FakeRadioLink();
              radio = ScriptedRadio(link);
              return link;
            }),
          ),
          messageNotifierProvider.overrideWithValue(FakeNotifier()),
          foregroundCheckProvider.overrideWithValue(() => true),
          reconnectDelaysProvider.overrideWithValue(const [
            Duration(milliseconds: 100),
          ]),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
    await tester.tap(find.byTooltip('Radio settings'));
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

  testWidgets('the radio battery is saved at connect and charted', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Battery and sensor history'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Battery and sensor history'));
    await settle(tester);

    expect(find.text('Radio telemetry'), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('4.06 V'), findsWidgets);
    expect(
      find.text('The chart appears after a second reading.'),
      findsOneWidget,
    );

    radio.selfTelemetry = [1, 116, 0x01, 0x90];
    await tester.tap(find.text('Request readings'));
    await settle(tester);
    expect(find.text('4.00 V'), findsWidgets);
    expect(find.textContaining('2 readings'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Battery chart')), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('the noise floor is saved at connect and charted', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Noise floor history'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Noise floor history'));
    await settle(tester);

    expect(find.text('-112 dBm'), findsWidgets);
    expect(find.text('Quiet. Weak signals get through.'), findsNothing);
    expect(find.text('Normal.'), findsOneWidget);
    expect(find.textContaining('receiving 10 min 0 s'), findsOneWidget);

    radio.noiseFloor = -98;
    await tester.tap(find.text('Read now'));
    await settle(tester);
    expect(find.text('-98 dBm'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Noise floor chart')), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('shows the radio and its details', (tester) async {
    await openSettings(tester);
    expect(find.text('Base'), findsOneWidget);
    expect(
      find.text('22 dBm (most this radio allows: 30 dBm)'),
      findsOneWidget,
    );
    expect(find.textContaining('910.525 MHz'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Battery'), 200);
    expect(find.text('4.01 V'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('renaming the radio changes it and shows the new name', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.text('Name'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Summit');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(radio.name, 'Summit');
    expect(
      find.text('Summit'),
      findsOneWidget,
      reason: 'read back from the radio',
    );
    await cleanUp(tester);
  });

  testWidgets('position is checked, then sent', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('Position'));
    await settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '95');
    await tester.enterText(fields.at(1), '-80.5');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.textContaining('Use decimal degrees'), findsOneWidget);

    await tester.enterText(fields.at(0), '35.25');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(radio.latitude, 35.25);
    expect(find.text('35.25000, -80.50000'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('sharing position and auto-add send the other params', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.text('Share position in adverts'));
    await settle(tester);
    expect(radio.locationPolicy, 1);

    await tester.scrollUntilVisible(
      find.text('Add new nodes automatically'),
      200,
    );
    await tester.tap(find.text('Add new nodes automatically'));
    await settle(tester);
    expect(radio.manualAdd, isTrue);
    expect(radio.locationPolicy, 1, reason: 'other fields keep their values');

    await tester.scrollUntilVisible(
      find.text('Still add repeaters automatically'),
      200,
    );
    await tester.tap(find.text('Still add repeaters automatically'));
    await settle(tester);
    expect(radio.autoAddFlags & AutoAddConfig.repeaters, isNonZero);
    await cleanUp(tester);
  });

  testWidgets('LoRa settings refuse a bad frequency and apply a good one', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.text('LoRa settings'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '3000');
    await tester.tap(find.text('Apply'));
    await settle(tester);
    expect(
      find.text('Frequency must be between 150 and 2500 MHz.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '869.525');
    await tester.tap(find.text('Apply'));
    await settle(tester);
    expect(radio.frequencyKhz, 869525);
    expect(find.textContaining('869.525 MHz'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('reboot asks first', (tester) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('Reboot radio'), 200);
    // Clear of the bottom edge, so the tap lands on the button.
    await tester.ensureVisible(find.text('Reboot radio'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await settle(tester);
    await tester.tap(find.text('Reboot radio'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(radio.reboots, 0);

    await tester.tap(find.text('Reboot radio'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Reboot'));
    await settle(tester);
    expect(radio.reboots, 1);
    await cleanUp(tester);
  });
}
