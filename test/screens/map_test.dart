import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/open_connect.dart';

import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/map_tab.dart';
import 'package:notoryx_core/screens/node_details.dart';

import '../support/fake_notifier.dart';
import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
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
  LatLng? phone;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openMap(WidgetTester tester) async {
    db = MeshDatabase.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          radioConnectorProvider.overrideWithValue(
            _Connector(() {
              final link = FakeRadioLink();
              ScriptedRadio(link)
                ..latitude = 35.20
                ..longitude = -80.80
                ..contacts.addAll([
                  contactFrame(
                    'Ridge RPT',
                    keyByte: 2,
                    type: NodeType.repeater,
                    latitude: 35.25,
                    longitude: -80.75,
                    lastModified: 11,
                  ),
                  contactFrame('No Position', keyByte: 3, lastModified: 12),
                ]);
              return link;
            }),
          ),
          messageNotifierProvider.overrideWithValue(FakeNotifier()),
          foregroundCheckProvider.overrideWithValue(() => true),
          mapTilesProvider.overrideWithValue(null),
          phonePositionProvider.overrideWithValue(() async => phone),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
    await openConnect(tester);
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
    await tester.tap(find.text('Map'));
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

  testWidgets('shows nodes that share a position and your radio', (
    tester,
  ) async {
    await openMap(tester);
    expect(find.bySemanticsLabel('Ridge RPT'), findsOneWidget);
    expect(find.bySemanticsLabel('No Position'), findsNothing);
    expect(find.bySemanticsLabel('Your radio'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('tapping a node shows its details with distance', (tester) async {
    await openMap(tester);
    await tester.tap(find.bySemanticsLabel('Ridge RPT'));
    await settle(tester);
    expect(find.text('Repeater'), findsOneWidget);
    expect(find.text('No route yet (messages flood)'), findsOneWidget);
    expect(find.text('Distance from your radio'), findsOneWidget);
    expect(find.text('7.2 km'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('my location shows the phone, or says location is off', (
    tester,
  ) async {
    phone = null;
    await openMap(tester);
    await tester.tap(find.byTooltip('Go to my location'));
    await settle(tester);
    expect(find.textContaining('Location is off'), findsOneWidget);

    phone = const LatLng(35.22, -80.84);
    await tester.tap(find.byTooltip('Go to my location'));
    await settle(tester);
    expect(find.bySemanticsLabel('You'), findsOneWidget);
    await cleanUp(tester);
  });

  test('helpers format time, routes and distance', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);
    expect(timeAgo(0, now), 'never');
    expect(timeAgo(1700000000 - 30, now), 'just now');
    expect(timeAgo(1700000000 - 600, now), '10 min ago');
    expect(timeAgo(1700000000 - 7200, now), '2 h ago');
    expect(timeAgo(1700000000 - 86400 * 3, now), '3 days ago');
    expect(routeText(pathUnknown), 'No route yet (messages flood)');
    expect(routeText(0), 'Direct');
    expect(routeText(0x42), '2 hops');
    expect(distanceText(const LatLng(0, 0), const LatLng(0, 0.001)), '111 m');
  });
}
