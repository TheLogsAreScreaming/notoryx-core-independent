import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/traffic.dart';
import 'package:notoryx_core/radio/radio.dart';

/// A raw packet: header byte, path length byte, path, payload.
Uint8List packet({
  required PayloadKind payload,
  bool flood = true,
  List<int> path = const [],
  int hashBytes = 1,
  List<int> body = const [],
}) => Uint8List.fromList([
  (flood ? 1 : 2) | (payload.value << 2),
  ((hashBytes - 1) << 6) | (path.length ~/ hashBytes),
  ...path,
  ...body,
]);

String key(String start) => start.padRight(64, '0');

void main() {
  final at = DateTime(2026, 11, 18, 12);
  final nodes = <TrafficNode>[
    (publicKey: key('aa11'), name: 'Ridge', at: const LatLng(35.3, -80.7)),
    (publicKey: key('bb22'), name: 'Valley', at: null),
    (publicKey: key('cc33'), name: 'Tower', at: const LatLng(35.25, -80.75)),
    // Two repeaters sharing the short ID dd: the nearer one should win.
    (publicKey: key('dd01'), name: 'Near', at: const LatLng(35.22, -80.78)),
    (publicKey: key('dd02'), name: 'Far', at: const LatLng(40.0, -75.0)),
  ];
  final self = (
    publicKey: key('ee55'),
    name: 'Base',
    at: const LatLng(35.2, -80.8),
  );

  TrafficRoute build(Uint8List raw) => buildTrafficRoute(
    raw: raw,
    snr: 7.25,
    rssi: -91,
    heardAt: at,
    nodes: nodes,
    self: self,
  )!;

  group('colour by type', () {
    test('each payload maps to one of six colours', () {
      expect(TrafficKind.of(PayloadKind.advert), TrafficKind.advert);
      expect(TrafficKind.of(PayloadKind.text), TrafficKind.direct);
      expect(TrafficKind.of(PayloadKind.request), TrafficKind.direct);
      expect(TrafficKind.of(PayloadKind.response), TrafficKind.direct);
      expect(TrafficKind.of(PayloadKind.groupText), TrafficKind.channel);
      expect(TrafficKind.of(PayloadKind.groupData), TrafficKind.channel);
      expect(TrafficKind.of(PayloadKind.ack), TrafficKind.ack);
      expect(TrafficKind.of(PayloadKind.trace), TrafficKind.trace);
      expect(TrafficKind.of(PayloadKind.path), TrafficKind.path);
      expect(TrafficKind.of(PayloadKind.control), TrafficKind.path);
      expect(TrafficKind.of(PayloadKind.unknown), TrafficKind.path);
    });

    test('the six colours are all different', () {
      final colours = {for (final k in TrafficKind.values) k.colour};
      expect(colours, hasLength(6));
    });
  });

  group('route building', () {
    test('a flooded advert runs origin → repeaters → this radio', () {
      final route = build(
        packet(
          payload: PayloadKind.advert,
          path: [0xcc, 0xbb],
          body: [0xaa, 0x11, ...List.filled(30, 0), 1, 2, 3],
        ),
      );
      expect(route.kind, TrafficKind.advert);
      expect(route.isFlood, isTrue);
      expect(route.hopCount, 2);
      expect(route.stops.map((s) => s.label), [
        'Ridge',
        'Tower',
        'Valley',
        'Base',
      ]);
      expect(route.summary, 'Ridge → Tower → Valley → Base');
      expect(route.stops.last.isSelf, isTrue);
      expect(route.heardFrom?.label, 'Valley');
    });

    test('hops with no position are skipped on the map', () {
      final route = build(
        packet(
          payload: PayloadKind.advert,
          path: [0xcc, 0xbb],
          body: [0xaa, 0x11, ...List.filled(30, 0)],
        ),
      );
      expect(route.points, const [
        LatLng(35.3, -80.7),
        LatLng(35.25, -80.75),
        LatLng(35.2, -80.8),
      ]);
      expect(route.offMap.map((s) => s.label), ['Valley']);
    });

    test('unknown hops keep their short ID and are off the map', () {
      final route = build(
        packet(payload: PayloadKind.groupText, path: [0x7f], body: [0x12]),
      );
      expect(route.kind, TrafficKind.channel);
      // Channel messages don't name the sender in the clear.
      expect(route.stops.map((s) => s.label), ['7F', 'Base']);
      expect(route.offMap.single.shortId, '7F');
      expect(route.points, const [LatLng(35.2, -80.8)]);
    });

    test('two-byte hop hashes are matched too', () {
      final route = build(
        packet(
          payload: PayloadKind.groupText,
          path: [0xcc, 0x33, 0xaa, 0x11],
          hashBytes: 2,
          body: [0x12],
        ),
      );
      expect(route.hopCount, 2);
      expect(route.stops.map((s) => s.label), ['Tower', 'Ridge', 'Base']);
    });

    test('a shared short ID picks the repeater nearest the last stop', () {
      final route = build(
        packet(payload: PayloadKind.ack, path: [0xdd], body: [1, 2, 3, 4]),
      );
      expect(route.kind, TrafficKind.ack);
      expect(route.stops.first.label, 'Near');
    });

    test('a direct message starts at its sender hash', () {
      final route = build(
        packet(
          payload: PayloadKind.text,
          flood: false,
          body: [0xee, 0xcc, 9, 9, 9],
        ),
      );
      expect(route.kind, TrafficKind.direct);
      expect(route.isFlood, isFalse);
      // No hops left, so it came straight to this radio.
      expect(route.stops.map((s) => s.label), ['Tower', 'Base']);
    });

    test('a direct packet still travelling does not end here', () {
      final route = build(
        packet(
          payload: PayloadKind.request,
          flood: false,
          path: [0xaa],
          body: [0x01, 0xcc, 9],
        ),
      );
      expect(route.stops.map((s) => s.label), ['Tower', 'Ridge']);
      expect(route.heardFrom, isNull);
    });

    test('a trace follows the hops in its payload', () {
      final route = build(
        packet(
          payload: PayloadKind.trace,
          flood: false,
          path: [20, 18],
          body: [1, 2, 3, 4, 5, 6, 7, 8, 0, 0xcc, 0xaa],
        ),
      );
      expect(route.kind, TrafficKind.trace);
      expect(route.stops.map((s) => s.label), ['Tower', 'Ridge']);
    });

    test('a repeater that is also the origin is not drawn twice', () {
      final route = build(
        packet(
          payload: PayloadKind.advert,
          path: [0xaa],
          body: [0xaa, 0x11, ...List.filled(30, 0)],
        ),
      );
      expect(route.stops.map((s) => s.label), ['Ridge', 'Base']);
    });

    test('junk is not a route', () {
      expect(
        buildTrafficRoute(
          raw: Uint8List.fromList([1]),
          snr: 0,
          rssi: 0,
          heardAt: at,
          nodes: nodes,
        ),
        isNull,
      );
    });

    test('travel time grows with legs, capped, and is zero when still', () {
      final route = build(
        packet(
          payload: PayloadKind.advert,
          path: [0xcc],
          body: [0xaa, 0x11, ...List.filled(30, 0)],
        ),
      );
      expect(trafficTravelTime(route), trafficLegTime * 2);
      expect(trafficTravelTime(route, reduceMotion: true), Duration.zero);
      final long = build(
        packet(
          payload: PayloadKind.groupText,
          path: [for (var i = 0; i < 12; i++) i.isEven ? 0xaa : 0xcc],
          body: [1],
        ),
      );
      expect(trafficTravelTime(long), trafficMaxTravel);
    });
  });

  group('traffic queue', () {
    late ProviderContainer container;
    late TrafficNotifier traffic;

    setUp(() {
      container = ProviderContainer(
        overrides: [connectionProvider.overrideWith(_Idle.new)],
      );
      traffic = container.read(trafficProvider.notifier);
      traffic.place = (nodes: nodes, self: self);
    });
    tearDown(() => container.dispose());

    RxLog log(PayloadKind payload) => RxLog(
      snr: 5,
      rssi: -100,
      packet: packet(payload: payload, path: [0xcc], body: [1, 2]),
    );

    test('nothing is kept while Traffic is off', () {
      traffic.heard(log(PayloadKind.groupText));
      expect(container.read(trafficProvider).busy, isFalse);
      expect(container.read(trafficProvider).latest, isNull);
    });

    test('at most three animate; the rest wait their turn', () {
      traffic.setOn(true);
      for (var i = 0; i < 5; i++) {
        traffic.heard(log(PayloadKind.groupText));
      }
      traffic.advance(Duration.zero);
      var state = container.read(trafficProvider);
      expect(state.active, hasLength(trafficMaxActive));
      expect(state.waiting, hasLength(2));
      expect(state.latest?.kind, TrafficKind.channel);

      // Once the first three have faded, the waiting two start.
      traffic.advance(const Duration(seconds: 10));
      state = container.read(trafficProvider);
      expect(state.active, hasLength(2));
      expect(state.waiting, isEmpty);
      expect(state.active.first.start, const Duration(seconds: 10));

      traffic.advance(const Duration(seconds: 20));
      expect(container.read(trafficProvider).busy, isFalse);
    });

    test('filtered-out kinds are ignored', () {
      traffic
        ..setOn(true)
        ..setShown({TrafficKind.advert});
      traffic.heard(log(PayloadKind.groupText));
      expect(container.read(trafficProvider).waiting, isEmpty);
      expect(container.read(trafficProvider).latest, isNull);
    });

    test('turning Traffic off clears the routes but keeps the filter', () {
      traffic
        ..setOn(true)
        ..setShown({TrafficKind.channel})
        ..heard(log(PayloadKind.groupText))
        ..setOn(false);
      final state = container.read(trafficProvider);
      expect(state.on, isFalse);
      expect(state.busy, isFalse);
      expect(state.latest, isNull);
      expect(state.shown, {TrafficKind.channel});
    });
  });
}

class _Idle extends ConnectionController {
  @override
  RadioConnectionState build() => const Disconnected();
}
