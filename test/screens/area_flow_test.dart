import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/presets/area_presets_provider.dart';
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

final _phoenixDoc = jsonEncode({
  'version': 2,
  'regions': [
    {
      'id': 'map-phx',
      'name': 'Phoenix, Arizona',
      'center': [33.45, -112.07],
      'radiusKm': 150,
      'frequencyMHz': 908.205,
      'bandwidthKHz': 62.5,
      'spreadingFactor': 9,
      'codingRate': 8,
      'updated': '2026-11-06',
      'source': 'map',
      'nodes': 219,
    },
    {
      'id': 'us-philadelphia',
      'name': 'Philadelphia',
      'center': [39.95, -75.17],
      'radiusKm': 100,
      'frequencyMHz': 919.5,
      'bandwidthKHz': 500,
      'spreadingFactor': 10,
      'codingRate': 5,
      'pathHashBytes': 2,
      'updated': '2026-10-17',
    },
  ],
});

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late ScriptedRadio radio;
  late MeshDatabase db;
  double? radioLat, radioLon;
  String? live;

  setUp(() {
    db = MeshDatabase.inMemory();
    radioLat = 33.5;
    radioLon = -112.0;
    live = null;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> connect(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          messageNotifierProvider.overrideWithValue(FakeNotifier()),
          foregroundCheckProvider.overrideWithValue(() => true),
          radioConnectorProvider.overrideWithValue(
            _Connector(() {
              final link = FakeRadioLink();
              radio = ScriptedRadio(link)
                ..latitude = radioLat
                ..longitude = radioLon;
              return link;
            }),
          ),
          areaPresetsFetchProvider.overrideWithValue(() async => live),
          bundledAreaPresetsProvider.overrideWithValue(() async => _phoenixDoc),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('MeshCore-Base'));
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

  testWidgets('offers the area settings, reviews and applies them', (
    tester,
  ) async {
    await connect(tester);
    expect(find.byKey(const ValueKey('area-banner')), findsOneWidget);
    expect(find.textContaining('219 on the MeshCore map'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await settle(tester);
    expect(find.text('• Frequency 910.525 → 908.205 MHz'), findsOneWidget);
    expect(find.text('• Spreading factor 7 → 9'), findsOneWidget);
    await tester.tap(find.text('Apply to radio'));
    await settle(tester);

    expect(radio.radioParamChanges, 1);
    expect(radio.frequencyKhz, 908205);
    expect(radio.bandwidthHz, 62500);
    expect(radio.spreadingFactor, 9);
    expect(radio.codingRate, 8);
    expect(
      find.byKey(const ValueKey('area-banner')),
      findsNothing,
      reason: 'the radio now reports the area settings',
    );
    expect(
      find.text('Radio set to Phoenix, Arizona settings.'),
      findsOneWidget,
    );
    await cleanUp(tester);
  });

  testWidgets('Not now hides the banner, and it stays hidden', (tester) async {
    await connect(tester);
    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(find.byKey(const ValueKey('area-banner')), findsNothing);
    expect(radio.radioParamChanges, 0);
    expect(
      await tester.runAsync(
        () => MeshStore(db).setting('area_preset_dismissed'),
      ),
      startsWith('map-phx|'),
    );
    await cleanUp(tester);
  });

  testWidgets(
    'no position and no choice: no banner; picking an area offers it',
    (tester) async {
      radioLat = null;
      radioLon = null;
      await connect(tester);
      expect(find.byKey(const ValueKey('area-banner')), findsNothing);

      await tester.tap(find.byTooltip('Local mesh settings'));
      await settle(tester);
      expect(find.textContaining('has no position'), findsOneWidget);
      await tester.tap(find.text('Philadelphia'));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      expect(find.textContaining('The Philadelphia mesh uses'), findsOneWidget);

      await tester.tap(find.text('Review'));
      await settle(tester);
      expect(find.textContaining('2-byte paths'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(radio.radioParamChanges, 0);
      await cleanUp(tester);
    },
  );

  testWidgets('the live list replaces the bundled one', (tester) async {
    live = jsonEncode({
      'version': 2,
      'regions': [
        {
          'id': 'map-phx',
          'name': 'Greater Phoenix',
          'center': [33.45, -112.07],
          'radiusKm': 150,
          'frequencyMHz': 908.205,
          'bandwidthKHz': 62.5,
          'spreadingFactor': 9,
          'codingRate': 8,
          'updated': '2026-11-07',
          'source': 'map',
        },
      ],
    });
    await connect(tester);
    expect(find.textContaining('Greater Phoenix'), findsOneWidget);
    expect(
      await tester.runAsync(() => MeshStore(db).setting('area_presets_cache')),
      contains('Greater Phoenix'),
    );
    await cleanUp(tester);
  });
}
