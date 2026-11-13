import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/route_planner.dart';
import 'package:notoryx_core/app/trace.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

Contact contact({
  int pathLength = pathUnknown,
  List<int> path = const [],
  NodeType type = NodeType.chat,
  String key = '42aa',
  String name = 'Hill',
}) => Contact(
  radioKey: 'r',
  publicKey: key.padRight(64, '0'),
  name: name,
  type: type.value,
  flags: 0,
  outPathLength: pathLength,
  outPath: Uint8List.fromList([...path, ...List.filled(64 - path.length, 0)]),
  lastAdvert: 0,
  lastModified: 0,
);

HeardPathRow heard(String hops, {int count = 1, double? snr, int size = 1}) =>
    HeardPathRow(
      id: 0,
      radioKey: 'r',
      hops: hops,
      hashBytes: size,
      count: count,
      lastSnr: snr,
      lastAt: 0,
    );

TraceData trace(List<double> snrs, double last) => TraceData(
  tag: 1,
  authCode: 0,
  hashBytes: 1,
  hashes: const [],
  snrs: snrs,
  finalSnr: last,
);

String name(String hash) => 'R-$hash';

void main() {
  test('link quality bands and the worse of two', () {
    expect(LinkQuality.fromSnr(null), LinkQuality.unknown);
    expect(LinkQuality.fromSnr(3), LinkQuality.good);
    expect(LinkQuality.fromSnr(-4), LinkQuality.fair);
    expect(LinkQuality.fromSnr(-12.5), LinkQuality.poor);
    expect(LinkQuality.good.worse(LinkQuality.poor), LinkQuality.poor);
    expect(LinkQuality.unknown.worse(LinkQuality.fair), LinkQuality.fair);
  });

  test('route hops come from the stored route, nearest first', () {
    expect(routeHops(contact()), isNull);
    expect(routeHops(contact(pathLength: 0)), isEmpty);
    expect(routeHops(contact(pathLength: 2, path: [0x11, 0x22])), ['11', '22']);
    final twoByte = contact(pathLength: 0x40 | 2, path: [1, 2, 3, 4]);
    expect(routeHashBytes(twoByte), 2);
    expect(routeHops(twoByte), ['0102', '0304']);
  });

  test('a trace to a person fills every link but the last, both ways', () {
    final c = contact(pathLength: 2, path: [0x11, 0x22]);
    final plan = planTrace(c)!;
    expect(plan.hops, hasLength(3), reason: 'out through 11, 22 and back');
    // 11 heard you, 22 heard 11, 11 heard 22, you heard 11.
    final legs = routeLegs(
      c,
      you: 'You',
      name: name,
      trace: trace([5, -3, -2], 6),
    );
    expect(
      [for (final l in legs) '${l.from}>${l.to}'],
      ['You>R-11', 'R-11>R-22', 'R-22>Hill'],
    );
    expect(
      [for (final l in legs) (l.out, l.back)],
      [(5.0, 6.0), (-3.0, -2.0), (null, null)],
    );
    expect(legs[1].quality, LinkQuality.fair);
    expect(legs[2].quality, LinkQuality.unknown);
  });

  test('a trace to a repeater measures the link to it too', () {
    final c = contact(
      pathLength: 1,
      path: [0x11],
      type: NodeType.repeater,
      name: 'Peak',
    );
    final legs = routeLegs(
      c,
      you: 'You',
      name: name,
      trace: trace([4, -14, -9], 2),
    );
    expect(
      [for (final l in legs) (l.out, l.back)],
      [(4.0, 2.0), (-14.0, -9.0)],
    );
    expect(legs[1].quality, LinkQuality.poor);
  });

  test('a trace that does not fit the route is ignored', () {
    final c = contact(pathLength: 2, path: [0x11, 0x22]);
    final legs = routeLegs(c, you: 'You', name: name, trace: trace([1], 1));
    expect(legs.every((l) => l.out == null && l.back == null), isTrue);
  });

  test('heard paths through the repeater next to them are offered', () {
    // Current route: you → 11 → 22 → Hill. The mesh has also carried
    // packets 22 → 33 → you, often and loudly.
    final c = contact(pathLength: 2, path: [0x11, 0x22]);
    final options = routeOptions(c, [
      heard('22>33', count: 9, snr: 7),
      heard('44>11', count: 1, snr: -13),
    ]);
    final routes = {for (final o in options) o.source: o};
    expect(routes.keys, containsAll(RouteSource.values));
    final alt = options.firstWhere((o) => o.source == RouteSource.heard);
    expect(alt.hops, ['33', '22']);
    expect(alt.weakest, LinkQuality.good);
    expect(alt.seenLinks, 2);

    final suggestion = suggestedRoute(options);
    expect(suggestion, same(alt));
    expect(options.first, same(alt), reason: 'best first');
  });

  test('a measured weak link marks the current route down', () {
    final c = contact(pathLength: 1, path: [0x11]);
    final before = routeOptions(
      c,
      const [],
    ).firstWhere((o) => o.source == RouteSource.current);
    final after = routeOptions(
      c,
      const [],
      trace: trace([-15], -16),
    ).firstWhere((o) => o.source == RouteSource.current);
    expect(after.weakest, LinkQuality.poor);
    expect(after.score, lessThan(before.score));
  });

  test('a repeater heard on paths gets a route through the hops after it', () {
    final c = contact(type: NodeType.repeater, key: '77ab', name: 'Ridge');
    final options = routeOptions(c, [heard('77>55', count: 4, snr: 2)]);
    final alt = options.firstWhere((o) => o.source == RouteSource.heard);
    expect(alt.hops, ['55']);
    expect(alt.links, 2, reason: 'you → 55 and 55 → Ridge');
  });

  test('no suggestion when nothing beats the route in use', () {
    final c = contact(pathLength: 0);
    expect(suggestedRoute(routeOptions(c, const [])), isNull);
  });

  test('routes must fit what the radio stores', () {
    expect(routeFits(const [], 1), isTrue);
    expect(routeFits(['11', '22'], 1), isTrue);
    expect(routeFits(['1122'], 1), isFalse);
    expect(routeFits(List.filled(33, 'aabb'), 2), isFalse);
    expect(routeFits(['11'], 4), isFalse);
    expect(routeBytes(['11', '22']), [0x11, 0x22]);
    expect(encodeRouteLength(3, 2), 0x43);
  });
}
