import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/contact_room.dart';
import 'package:notoryx_core/data/data.dart';

Contact _c(String name, {int lastAdvert = 0, bool favourite = false}) =>
    Contact(
      radioKey: 'r',
      publicKey: name,
      name: name,
      type: 1,
      flags: favourite ? 1 : 0,
      outPathLength: 0xFF,
      outPath: Uint8List(0),
      lastAdvert: lastAdvert,
      lastModified: 0,
    );

void main() {
  test('meter levels', () {
    expect(const ContactMeter(10, 100).level, ContactLevel.ok);
    expect(const ContactMeter(89, 100).level, ContactLevel.ok);
    expect(const ContactMeter(90, 100).level, ContactLevel.nearlyFull);
    expect(const ContactMeter(90, 100).free, 10);
    expect(const ContactMeter(100, 100).level, ContactLevel.full);
    expect(const ContactMeter(120, 100).fraction, 1);
    expect(const ContactMeter(120, 100).free, 0);
  });

  test('candidates skip favourites, oldest first', () {
    final list = removalCandidates([
      _c('b', lastAdvert: 50),
      _c('fav', favourite: true),
      _c('a', lastAdvert: 50),
      _c('never'),
      _c('new', lastAdvert: 900),
    ]);
    expect(list.map((c) => c.name), ['never', 'a', 'b', 'new']);
  });

  test('last heard in words', () {
    final now = DateTime.utc(2026, 11, 7, 12);
    int ago(Duration d) => now.subtract(d).millisecondsSinceEpoch ~/ 1000;
    expect(lastHeard(0, now), 'never heard');
    expect(
      lastHeard(ago(const Duration(minutes: 5)), now),
      'heard in the last hour',
    );
    expect(lastHeard(ago(const Duration(hours: 5)), now), 'heard 5 h ago');
    expect(lastHeard(ago(const Duration(days: 1)), now), 'heard yesterday');
    expect(lastHeard(ago(const Duration(days: 12)), now), 'heard 12 days ago');
    expect(lastHeard(ago(const Duration(days: 95)), now), 'heard 3 months ago');
    expect(lastHeard(5, now), 'heard long ago');
  });
}
