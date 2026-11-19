import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/open_connect.dart';

import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/app/traffic.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/map_tab.dart';
import 'package:notoryx_core/screens/node_details.dart';
import 'package:notoryx_core/screens/range_rings_layer.dart';

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

  Future<void> openMap(
    WidgetTester tester, {
    List<List<int>> extra = const [],
  }) async {
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
                  ...extra,
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

  testWidgets('Traffic draws heard packets with a route card and legend', (
    tester,
  ) async {
    await openMap(tester);
    expect(find.byKey(const Key('traffic-card')), findsNothing);
    await tester.tap(find.byKey(const Key('map-traffic')));
    await settle(tester);
    expect(find.text('Listening for packets…'), findsOneWidget);
    expect(find.text('Acknowledgement'), findsOneWidget);

    // A channel message flooded through Ridge RPT (key 02…) and an
    // unknown repeater 7F.
    final traffic = ProviderScope.containerOf(
      tester.element(find.byType(MapTab)),
    ).read(trafficProvider.notifier);
    traffic.heard(
      RxLog(snr: 6.5, rssi: -88, packet: [0x15, 0x02, 0x02, 0x7f, 0x11]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ridge RPT → 7F → Base'), findsOneWidget);
    expect(find.text('Channel message'), findsWidgets);
    expect(find.text('Heard from 7F · 6.50 dB'), findsOneWidget);
    expect(find.textContaining('Flood 2 · -88 dBm'), findsOneWidget);
    expect(find.text('Not on map: 7F'), findsOneWidget);

    // Tapping the card shows the packet stop by stop.
    await tester.tap(find.byKey(const Key('traffic-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Packet details'), findsOneWidget);
    expect(find.text('Base (This radio)'), findsOneWidget);
    expect(find.text('7F · Not on map'), findsOneWidget);
    await tester.drag(find.text('Packet details'), const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Raw packet, 5 bytes'), findsOneWidget);
    expect(find.text('15 02 02 7F 11'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // It plays out and the layer goes quiet again.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(
      ProviderScope.containerOf(tester.element(find.byType(MapTab)))
          .read(trafficProvider)
          .busy,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('map-traffic')));
    await settle(tester);
    expect(find.byKey(const Key('traffic-card')), findsNothing);
    await cleanUp(tester);
  });

  testWidgets('the options menu holds the other map tools', (tester) async {
    await openMap(tester);
    await tester.tap(find.byKey(const Key('map-options')));
    await settle(tester);
    expect(find.text('Offline map packs'), findsOneWidget);
    expect(find.text('Zone & trail alerts'), findsOneWidget);
    await tester.tap(find.text('Zone & trail alerts'));
    await settle(tester);
    expect(find.textContaining('No zones yet'), findsOneWidget);
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

  testWidgets('a node not heard for a day is faded and said to be stale', (
    tester,
  ) async {
    final old = DateTime.now()
        .subtract(const Duration(days: 3))
        .millisecondsSinceEpoch;
    await openMap(
      tester,
      extra: [
        contactFrame(
          'Old Hill',
          keyByte: 4,
          type: NodeType.repeater,
          latitude: 35.10,
          longitude: -81.40,
          lastModified: 13,
          lastAdvert: old ~/ 1000,
        ),
      ],
    );
    final stale = find.bySemanticsLabel(RegExp(r'^Old Hill, stale · '));
    expect(stale, findsOneWidget);
    expect(
      find.ancestor(
        of: stale,
        matching: find.byWidgetPredicate(
          (w) => w is Opacity && w.opacity == 0.45,
        ),
      ),
      findsOneWidget,
    );
    // Never heard is never stale.
    expect(find.bySemanticsLabel('Ridge RPT'), findsOneWidget);
    // The Contacts list says so in words, with an icon.
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    expect(find.text('stale · 3 days ago'), findsOneWidget);
    expect(find.byIcon(Icons.history_toggle_off), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('range rings toggle from the options menu', (tester) async {
    await openMap(tester);
    expect(find.byType(RangeRingsLayer), findsNothing);
    await tester.tap(find.byKey(const Key('map-options')));
    await settle(tester);
    await tester.tap(find.text('Show range rings'));
    await settle(tester);
    expect(find.byType(RangeRingsLayer), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d (m|km|mi)$')), findsNWidgets(4));
    expect(find.bySemanticsLabel(RegExp('^Range rings at ')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-options')));
    await settle(tester);
    await tester.tap(find.text('Hide range rings'));
    await settle(tester);
    expect(find.byType(RangeRingsLayer), findsNothing);
    await cleanUp(tester);
  });
}
