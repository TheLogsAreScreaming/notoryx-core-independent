import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/channel_conflicts.dart';

SlotState s(int slot, String name, int fill) =>
    (slot: slot, name: name, secret: Uint8List.fromList(List.filled(16, fill)));

void main() {
  test('changed and emptied slots are mismatches; new slots are not', () {
    final found = compareSlots(
      mine: [s(0, 'Public', 1), s(1, 'Crew', 2), s(2, 'Base', 3)],
      radio: [s(0, 'Public', 1), s(1, 'Crew', 5), s(2, '', 0), s(4, 'New', 6)],
      count: 8,
    );
    expect(found.map((m) => m.mine.slot), [1, 2]);
    expect(found.first.radio!.secret.first, 5);
    expect(found.last.radio, isNull);
  });

  test('waiting copies stand until the radio agrees with them', () {
    final waiting = [s(1, 'Crew', 2)];
    expect(
      compareSlots(
        mine: [s(1, 'Crew', 5)],
        radio: [s(1, 'Crew', 5)],
        count: 8,
        waiting: waiting,
      ),
      hasLength(1),
    );
    expect(
      compareSlots(
        mine: [s(1, 'Crew', 5)],
        radio: [s(1, 'Crew', 2)],
        count: 8,
        waiting: waiting,
      ),
      isEmpty,
    );
  });

  test('slots past the count are ignored; saved form round-trips', () {
    expect(compareSlots(mine: [s(9, 'Far', 1)], radio: [], count: 8), isEmpty);
    final list = compareSlots(
      mine: [s(1, 'Crew', 2), s(3, 'Ops', 4)],
      radio: [s(1, 'Crew', 9)],
      count: 8,
    );
    final back = decodeMismatches(encodeMismatches(list));
    expect(back.map((m) => m.mine.slot), [1, 3]);
    expect(back.first.radio!.secret.first, 9);
    expect(back.last.radio, isNull);
    expect(decodeMismatches('{'), isEmpty);
    expect(
      secretTag(s(0, '', 7).secret),
      matches(RegExp(r'^[0-9a-f]{4} [0-9a-f]{4}$')),
    );
  });
}
