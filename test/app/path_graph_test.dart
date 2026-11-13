import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/screens/network_diagram.dart';
import 'package:notoryx_core/app/path_graph.dart';
import 'package:notoryx_core/data/data.dart';

HeardPathRow path(String hops, int count, double? snr) => HeardPathRow(
  id: 0,
  radioKey: 'r',
  hops: hops,
  hashBytes: 1,
  count: count,
  lastSnr: snr,
  lastAt: 0,
);

void main() {
  test('network: repeaters on rings by hops, links weighted by packets', () {
    final net = pathNetwork([
      path('a1>b2', 3, null), // a1 two hops out, b2 next to you
      path('c3>b2', 1, null),
      path('b2', 2, null),
    ]);
    expect(net.nodes['b2'], (ring: 1, relayed: 6));
    expect(net.nodes['a1'], (ring: 2, relayed: 3));
    expect(net.nodes['c3']!.ring, 2);
    expect(net.nodes[networkSelf]!.ring, 0);
    expect(net.links[('b2', networkSelf)], 6);
    expect(net.links[('a1', 'b2')], 3);
    expect(net.links[('c3', 'b2')], 1);
    expect(pathNetwork(const []).nodes.keys, [networkSelf]);
  });

  test('network keeps only the busiest repeaters, and their links', () {
    final net = pathNetwork([
      for (var i = 0; i < 20; i++)
        path('${i.toRadixString(16)}0>ff', i + 1, null),
    ], maxNodes: 5);
    expect(net.nodes, hasLength(6));
    expect(net.nodes.containsKey('ff'), isTrue);
    for (final (a, b) in net.links.keys) {
      expect(net.nodes.containsKey(a), isTrue);
      expect(net.nodes.containsKey(b), isTrue);
    }
  });

  test('network layout: you centred, rings at even steps, tappable', () {
    final net = pathNetwork([path('a1>b2', 3, null), path('b2', 2, null)]);
    final layout = layoutNetwork(net, const Size(300, 300));
    expect(layout.centers[networkSelf], const Offset(150, 150));
    for (final MapEntry(:key, :value) in net.nodes.entries) {
      expect(
        (layout.centers[key]! - layout.center).distance,
        closeTo(layout.gap * value.ring, .001),
      );
    }
    expect(layout.hit(layout.centers['a1']!), 'a1');
    expect(layout.hit(const Offset(-40, -40)), isNull);
  });

  test('groups paths by the repeater heard directly, most heard first', () {
    final direct = directRepeaters([
      path('aa>bb', 3, 4),
      path('cc>bb', 1, 8),
      path('dd', 10, -2),
    ]);
    expect([for (final d in direct) d.hash], ['dd', 'bb']);
    final bb = direct[1];
    expect(bb.heard, 4);
    expect(bb.averageSnr, closeTo(5, 0.001)); // (4*3 + 8*1) / 4
    expect(bb.paths.first.hops, 'aa>bb');
  });

  test('hop names: unique match, several, or none', () {
    final known = [
      (name: 'Hilltop', publicKey: 'ab12${'0' * 60}'),
      (name: 'Valley', publicKey: 'ab34${'0' * 60}'),
      (name: 'Ridge', publicKey: 'cd00${'0' * 60}'),
    ];
    expect(hopName('cd', known), 'Ridge');
    expect(hopName('ab12', known), 'Hilltop');
    expect(hopName('ab', known), 'AB (Hilltop or Valley)');
    expect(hopName('ef', known), 'EF');
  });

  test('paths round-trip through their stored form', () {
    expect(pathHops(pathKey(['aa', 'bb'])), ['aa', 'bb']);
    expect(pathHops(''), isEmpty);
  });

  test('a path heard again adds to its count', () async {
    final db = MeshDatabase.inMemory();
    for (var i = 0; i < 2; i++) {
      await db.customStatement(
        'INSERT INTO heard_paths '
        '(radio_key, hops, hash_bytes, count, last_snr, last_at) '
        'VALUES (?, ?, ?, 1, ?, ?) '
        'ON CONFLICT(radio_key, hops) DO UPDATE SET '
        'count = count + 1, last_snr = excluded.last_snr, '
        'last_at = excluded.last_at',
        ['r', 'aa>bb', 1, 2.5 + i, i],
      );
    }
    final rows = await db.select(db.heardPaths).get();
    expect(rows.single.count, 2);
    expect(rows.single.lastSnr, 3.5);
    await clearHeardPaths(db, 'r');
    expect(await db.select(db.heardPaths).get(), isEmpty);
    await db.close();
  });
}
