// Renders the README screenshots from the real screens, driven by the
// scripted test radio and made-up data. Not part of `flutter test`.
//
//   flutter test tools/screenshots --update-goldens
//
// The pictures land in docs/screenshots/.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/app_background.dart';
import 'package:notoryx_core/app/compass.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/keep_alive.dart';
import 'package:notoryx_core/app/node_look.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/app/terrain_profile.dart';
import 'package:notoryx_core/app/traffic.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/presets/area_presets_provider.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/map_tab.dart';

import '../../test/support/fake_radio_link.dart';
import '../../test/support/radio_frames.dart';
import '../../test/support/scripted_radio.dart';

class _Connector implements RadioConnector {
  _Connector(this.newLink);
  final FakeRadioLink Function() newLink;

  @override
  bool get supportsUsb => false;

  @override
  Stream<BleTarget> scanBluetooth({bool all = false}) => Stream.fromIterable(
    const [BleTarget(deviceId: 'aa', label: 'MeshCore-Base', rssi: -60)],
  );

  @override
  Future<List<UsbTarget>> listUsb() async => const [];

  @override
  Future<RadioLink> open(RadioTarget target) async => newLink();
}

class _Keeper implements BackgroundKeeper {
  @override
  Future<void> start(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<bool> batteryUnrestricted() async => true;
  @override
  Future<void> requestBatteryUnrestricted() async {}
}

class _Notifier implements MessageNotifier {
  @override
  Future<ChatLink?> init(void Function(ChatLink chat) onOpen) async => null;
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required ChatLink chat,
  }) async {}
}

class _Compass implements CompassSource {
  final controller = StreamController<HeadingReading>.broadcast();
  @override
  Future<bool> available() async => true;
  @override
  Stream<HeadingReading> headings() => controller.stream;
  @override
  Future<double?> declination(LatLng at) async => 0;
}

const _home = LatLng(46.5, -121.25);

/// A made-up valley with one hill that cuts into the Fresnel zone.
double _ground(double t) =>
    600 +
    40 * t -
    70 * math.sin(math.pi * t) +
    55 * math.exp(-math.pow((t - 0.55) / 0.08, 2)) +
    4 * math.sin(23 * t);

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// A channel message stamped [minutesAgo] before now.
List<int> _channelMessage(String text, int channel, int minutesAgo) => [
  ResponseCode.channelMessageV3,
  12,
  0,
  0,
  channel,
  pathUnknown,
  0,
  ...u32(_now() - minutesAgo * 60),
  ...utf8.encode(text),
];

String _hexKey(int b) =>
    List.filled(32, b.toRadixString(16).padLeft(2, '0')).join();

Future<void> _loadFonts() async {
  final cache =
      '${Platform.environment['HOME']}/flutter-stable/bin/cache/'
      'artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$cache/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
    'Roboto-Italic.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(_loadFonts);

  late FakeRadioLink link;
  late ScriptedRadio radio;
  late MeshDatabase db;
  late _Compass compass;

  setUp(() {
    db = MeshDatabase.inMemory();
    compass = _Compass();
  });

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> start(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    WidgetsApp.debugAllowBannerOverride = false;
    debugDisableShadows = false;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    final connector = _Connector(() {
      link = FakeRadioLink();
      radio = ScriptedRadio(link)
        ..name = 'Basecamp'
        ..latitude = _home.latitude
        ..longitude = _home.longitude;
      radio.contacts
        ..clear()
        ..addAll([
          contactFrame(
            'Maya',
            keyByte: 2,
            lastModified: 10,
            latitude: 46.53,
            longitude: -121.21,
            lastAdvert: _now() - 300,
          ),
          contactFrame(
            'Ridge Repeater',
            keyByte: 3,
            lastModified: 11,
            type: NodeType.repeater,
            latitude: 46.62,
            longitude: -121.38,
            lastAdvert: _now() - 900,
          ),
          contactFrame(
            'Trailhead Room',
            keyByte: 4,
            lastModified: 12,
            type: NodeType.room,
            latitude: 46.45,
            longitude: -121.30,
            lastAdvert: _now() - 3600,
          ),
          contactFrame(
            'Fire Tower',
            keyByte: 5,
            lastModified: 13,
            type: NodeType.repeater,
            latitude: 46.70,
            longitude: -121.10,
            lastAdvert: _now() - 7200,
          ),
          contactFrame(
            'Sam',
            keyByte: 6,
            lastModified: 14,
            lastAdvert: _now() - 86400,
          ),
        ]);
      return link;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          radioConnectorProvider.overrideWithValue(connector),
          messageNotifierProvider.overrideWithValue(_Notifier()),
          keepAliveProvider.overrideWithValue(_Keeper()),
          areaPresetsFetchProvider.overrideWithValue(() async => null),
          mapTilesProvider.overrideWithValue(null),
          phonePositionProvider.overrideWithValue(() async => _home),
          compassSourceProvider.overrideWithValue(compass),
          powerSaveProvider.overrideWith((ref) async => false),
          elevationLookupProvider.overrideWithValue(
            (points) async => [
              for (var i = 0; i < points.length; i++)
                _ground(i / (points.length - 1)),
            ],
          ),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
    final button = find.byTooltip('Connect a radio');
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button);
      await settle(tester);
    }
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester, 20);
    radio.queue.addAll([
      _channelMessage('Ridge: snow line is down to 5,000 ft', 1, 42),
      _channelMessage('Maya: chains needed past the gate', 1, 31),
      _channelMessage('Ridge: copy, heading to the hut', 1, 12),
      _channelMessage('Fire Tower: net check-in at 19:00', 0, 25),
      _channelMessage('Sam: anyone near the lake?', 0, 6),
    ]);
    link.emit([PushCode.messagesWaiting]);
    await settle(tester, 20);
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(NotoryxApp),
    matchesGoldenFile('../../docs/screenshots/$name.png'),
  );

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
    debugDisableShadows = true;
  }

  Future<void> colours() => MeshStore(db).let((store) async {
    await saveNodeLook(store, _hexKey(2), const NodeColour(Color(0xFF00897B)));
    await saveNodeLook(store, _hexKey(3), const NodeColour(Color(0xFFEF6C00)));
    await saveNodeLook(store, _hexKey(5), const NodeColour(Color(0xFFC62828)));
  });

  testWidgets('chats, conversation, contacts, node, terrain, compass', (
    tester,
  ) async {
    await tester.runAsync(colours);
    await start(tester);
    await shot(tester, 'chats');

    await tester.tap(find.text('#trail'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'On my way, 20 min out');
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
    await shot(tester, 'conversation');
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Contacts'));
    await settle(tester);
    await shot(tester, 'contacts');

    await tester.tap(find.byTooltip('Details for Ridge Repeater'));
    await settle(tester);
    await shot(tester, 'node');

    await tester.tap(find.text('Terrain'));
    await settle(tester);
    await tester.tap(find.text('Check terrain'));
    await settle(tester);
    await shot(tester, 'terrain');
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.byTooltip('Details for Ridge Repeater'));
    await settle(tester);
    await tester.tap(find.text('Compass'));
    await settle(tester);
    for (var i = 0; i < 30; i++) {
      compass.controller.add((heading: 300, accuracy: 3));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);
    await shot(tester, 'compass');
    await finish(tester);
  });

  testWidgets('live traffic on the map', (tester) async {
    await tester.runAsync(colours);
    await start(tester);
    await tester.tap(find.text('Map'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('map-traffic')));
    await settle(tester);
    final traffic = ProviderScope.containerOf(
      tester.element(find.byType(MapTab)),
    ).read(trafficProvider.notifier);
    // A channel message on its way in: Fire Tower, then Ridge Repeater.
    traffic.heard(
      RxLog(snr: 4.75, rssi: -97, packet: [0x15, 0x02, 0x05, 0x03, 0x11]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Maya's advert flooded through Fire Tower, an unknown repeater and
    // Ridge Repeater.
    traffic.heard(
      RxLog(
        snr: 9.25,
        rssi: -82,
        packet: [
          0x11,
          0x03,
          0x05,
          0x7f,
          0x03,
          ...List.filled(32, 2),
          ...List.filled(70, 0),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await shot(tester, 'traffic');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await finish(tester);
  });

  testWidgets('glass over a mesh gradient', (tester) async {
    await tester.runAsync(() async {
      await colours();
      await MeshStore(db).saveSetting(
        backgroundSetting,
        const AppBackground(
          kind: BackgroundKind.mesh,
          first: Color(0xFF0D47A1),
          second: Color(0xFF6A1B9A),
        ).encode(),
      );
    });
    await start(tester);
    await shot(tester, 'background');
    await finish(tester);
  });
}

extension<T> on T {
  R let<R>(R Function(T it) f) => f(this);
}
