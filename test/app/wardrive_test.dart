import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/wardrive.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/protocol/commands.dart';
import 'package:notoryx_core/radio/protocol/discover.dart';

void main() {
  test('the ping asks only repeaters, with its tag', () {
    expect(discoverRequest(0x01020304), [0x80, 0x04, 4, 3, 2, 1]);
    expect(SendControlData(discoverRequest(1)).encode(), [
      55,
      0x80,
      0x04,
      1,
      0,
      0,
      0,
    ]);
  });

  test('a repeater answer is read; others are not', () {
    final key = List.generate(32, (i) => i);
    final answer = Uint8List.fromList([0x92, 0xF8, 7, 0, 0, 0, ...key]);
    final a = parseDiscoverAnswer(answer)!;
    expect(a.tag, 7);
    expect(a.heardUs, -2.0);
    expect(a.publicKey, startsWith('000102'));
    expect(
      parseDiscoverAnswer(Uint8List.fromList([0x91, ...answer.sublist(1)])),
      isNull,
    );
    expect(parseDiscoverAnswer(Uint8List(10)), isNull);
  });

  test('the best link is the best of each repeater’s weaker side', () {
    expect(bestLink([]), isNull);
    expect(bestLink([(heardUs: 10, weHeard: -3), (heardUs: 2, weHeard: 4)]), 2);
  });

  test('deleting a drive removes its pings and hits', () async {
    final db = MeshDatabase.inMemory();
    final drive = await db
        .into(db.wardrives)
        .insert(WardrivesCompanion.insert(name: 'd', startedAt: 1));
    final ping = await db
        .into(db.wardrivePings)
        .insert(
          WardrivePingsCompanion.insert(
            drive: drive,
            at: 1,
            latitude: 1,
            longitude: 2,
          ),
        );
    await db
        .into(db.wardriveHits)
        .insert(
          WardriveHitsCompanion.insert(
            ping: ping,
            repeaterKey: 'ab',
            heardUs: 1,
            weHeard: 2,
            rssi: -90,
          ),
        );
    await deleteWardrive(db, drive);
    expect(await db.select(db.wardriveHits).get(), isEmpty);
    expect(await db.select(db.wardrivePings).get(), isEmpty);
    expect(await db.select(db.wardrives).get(), isEmpty);
    await db.close();
  });
}
