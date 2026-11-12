import 'package:flutter_test/flutter_test.dart';
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
