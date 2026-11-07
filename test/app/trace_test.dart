import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/trace.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

Contact _contact({
  required int pathLength,
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

void main() {
  test('a repeater two hops away is traced out through it and back', () {
    final plan = planTrace(
      _contact(pathLength: 1, path: [0x11], type: NodeType.repeater),
    )!;
    expect(plan.hashBytes, 1);
    expect(plan.hops, [
      [0x11],
      [0x42],
      [0x11],
    ]);
  });

  test('a neighbouring repeater is traced in one hop', () {
    final plan = planTrace(_contact(pathLength: 0, type: NodeType.room))!;
    expect(plan.hops, [
      [0x42],
    ]);
  });

  test('a person is traced as far as the last repeater on the route', () {
    final plan = planTrace(_contact(pathLength: 2, path: [0x11, 0x22]))!;
    expect(plan.hops, [
      [0x11],
      [0x22],
      [0x11],
    ]);
  });

  test('two-byte hashes are kept whole', () {
    final plan = planTrace(
      _contact(
        pathLength: 0x40 | 1,
        path: [0x11, 0x12],
        type: NodeType.repeater,
      ),
    )!;
    expect(plan.hashBytes, 2);
    expect(plan.hops, [
      [0x11, 0x12],
      [0x42, 0xaa],
      [0x11, 0x12],
    ]);
  });

  test('nothing to trace without a route or past a direct person', () {
    expect(planTrace(_contact(pathLength: pathUnknown)), isNull);
    expect(planTrace(_contact(pathLength: 0)), isNull);
    expect(
      planTrace(_contact(pathLength: 0x80 | 1, path: [1, 2, 3])),
      isNull,
      reason: 'three-byte hashes',
    );
  });

  test('legs are named from contacts, out and back', () {
    final trace = TraceData(
      tag: 1,
      authCode: 0,
      hashBytes: 1,
      hashes: [0x11, 0x42, 0x11],
      snrs: [-5, 2.5, 7],
      finalSnr: 6,
    );
    final legs = traceLegs(trace, [
      _contact(pathLength: 0, key: '42aa', name: 'Hill RPT'),
    ]);
    expect(legs.map((l) => '${l.from}>${l.to} ${l.snr}'), [
      'You>11 -5.0',
      '11>Hill RPT 2.5',
      'Hill RPT>11 7.0',
      '11>You 6.0',
    ]);
  });
}
