import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/follow.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

Contact _at(double lat, double lon) => Contact(
  radioKey: 'r',
  publicKey: 'aa',
  name: 'Hiker',
  type: 1,
  flags: 0,
  outPathLength: 0,
  outPath: Uint8List(0),
  lastAdvert: 0,
  lastModified: 0,
  latitude: lat,
  longitude: lon,
);

void main() {
  test('reads the position out of a telemetry reply', () {
    expect(
      positionIn(const [
        LppReading(1, LppKind.voltage, [4.1]),
        LppReading(1, LppKind.gps, [45.5, -122.6, 100]),
      ]),
      const LatLng(45.5, -122.6),
    );
    expect(
      positionIn(const [
        LppReading(1, LppKind.gps, [0, 0, 0]),
      ]),
      isNull,
    );
  });

  test('follows: asks, takes adverts, merges small moves, stops', () async {
    final contacts = StreamController<List<Contact>>.broadcast();
    var answer = const LatLng(45.51, -122.6);
    final c = ProviderContainer(
      overrides: [
        followAskProvider.overrideWithValue((_) async => answer),
        contactsProvider.overrideWith((ref, _) => contacts.stream),
      ],
    );
    // Teardowns run last first: the container lets go of the stream, then
    // the stream can close.
    addTearDown(contacts.close);
    addTearDown(c.dispose);
    // Like the follow screen: a provider nobody listens to is paused.
    final watching = c.listen(followProvider, (_, _) {});
    addTearDown(watching.close);
    final follow = c.read(followProvider.notifier);

    follow.start(
      radioKey: 'r',
      nodeKey: 'aa',
      name: 'Hiker',
      lastKnown: const LatLng(45.5, -122.6),
    );
    await pumpEventQueue();
    var s = c.read(followProvider)!;
    expect(s.asked, 1);
    expect(s.answered, 1);
    expect(s.trail, hasLength(2));
    expect(s.trail.last.asked, isTrue);
    expect(follow.remaining(), greaterThan(const Duration(minutes: 14)));

    answer = const LatLng(45.51001, -122.6);
    await follow.askNow();
    expect(c.read(followProvider)!.trail, hasLength(2));

    // The same advert again after a fresher reply adds nothing.
    contacts.add([_at(45.5, -122.6)]);
    await pumpEventQueue();
    expect(c.read(followProvider)!.trail, hasLength(2));

    contacts.add([_at(45.53, -122.6)]);
    await pumpEventQueue();
    s = c.read(followProvider)!;
    expect(s.trail, hasLength(3));
    expect(s.trail.last.asked, isFalse);

    follow.stop();
    expect(c.read(followProvider), isNull);
  });

  test('without a radio to ask it only watches', () async {
    final c = ProviderContainer(
      overrides: [
        followAskProvider.overrideWithValue((_) => null),
        contactsProvider.overrideWith((ref, _) => const Stream.empty()),
      ],
    );
    addTearDown(c.dispose);
    c
        .read(followProvider.notifier)
        .start(radioKey: 'r', nodeKey: 'aa', name: 'Hiker');
    await pumpEventQueue();
    expect(c.read(followProvider)!.asked, 0);
  });
}
