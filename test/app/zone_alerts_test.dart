import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/zone_alerts.dart';
import 'package:notoryx_core/data/data.dart';

// About 111 m per 0.001 degree of latitude.
const lat0 = 45.0, lon0 = -110.0;
Watched at(double dLat, double dLon, {String key = 'a'}) =>
    (key: key, name: 'Ann', lat: lat0 + dLat, lon: lon0 + dLon);
const Zone camp = (
  id: 'camp',
  name: 'Camp',
  lat: lat0,
  lon: lon0,
  radius: 200,
  on: ZoneAlertOn.both,
);

Contact contact(String key, {bool favourite = false, double? lat}) => Contact(
  radioKey: 'r',
  publicKey: key,
  type: 1,
  flags: favourite ? 1 : 0,
  outPathLength: -1,
  outPath: Uint8List(0),
  name: 'C$key',
  lastAdvert: 0,
  latitude: lat,
  longitude: lat == null ? null : lon0,
  lastModified: 0,
);

void main() {
  test('distances', () {
    expect(metresBetween(lat0, lon0, lat0 + .001, lon0), closeTo(111.2, .5));
    final trail = [(lat: lat0, lon: lon0), (lat: lat0, lon: lon0 + .01)];
    expect(metresFromTrail(lat0 + .001, lon0 + .005, trail), closeTo(111, 1));
    expect(metresFromTrail(lat0, lon0, const []), isNull);
    expect(shortDistance(120), '120 m');
    expect(shortDistance(1500), '1.5 km');
  });

  test('zones: silent first sighting, one alert per crossing, no wobble', () {
    final w = ZoneWatcher();
    expect(w.observe([at(0, 0)], zones: [camp]), isEmpty);
    final left = w.observe([at(.003, 0)], zones: [camp]);
    expect(left.single.kind, ZoneAlertKind.left);
    expect(w.observe([at(.0035, 0)], zones: [camp]), isEmpty);
    expect(
      w.observe([at(0, 0)], zones: [camp]).single.kind,
      ZoneAlertKind.entered,
    );
    // ~210 m: outside 200 m but inside the slack.
    expect(w.observe([at(.00189, 0)], zones: [camp]), isEmpty);
  });

  test('trail: alerts once, re-arms after coming back', () {
    final w = ZoneWatcher();
    final trail = [(lat: lat0, lon: lon0), (lat: lat0, lon: lon0 + .02)];
    List<ZoneAlert> look(double d) =>
        w.observe([at(d, .01)], zones: const [], trail: trail);
    expect(look(0), isEmpty);
    expect(look(.0015).single.kind, ZoneAlertKind.offTrail);
    expect(look(.002), isEmpty);
    expect(look(.0003), isEmpty);
    expect(look(.0015), hasLength(1));
    final fresh = ZoneWatcher();
    expect(
      fresh.observe([at(.01, .01)], zones: const [], trail: trail),
      isEmpty,
    );
    expect(
      fresh.observe([at(.011, .01)], zones: const [], trail: trail),
      isEmpty,
    );
  });

  test('settings survive encoding and junk is ignored', () {
    final s = ZoneSettings.decode(
      const ZoneSettings(
        enabled: true,
        favouritesOnly: false,
        includeRadio: false,
        zones: [camp],
        trackId: 7,
        offTrailMetres: 250,
      ).encode(),
    );
    expect(s.enabled, isTrue);
    expect(s.favouritesOnly, isFalse);
    expect(s.includeRadio, isFalse);
    expect(s.zones.single.name, 'Camp');
    expect(s.trackId, 7);
    expect(s.offTrailMetres, 250);
    expect(ZoneSettings.decode('nope').enabled, isFalse);
    expect(ZoneSettings.decode(null).favouritesOnly, isTrue);
  });

  test('who is watched', () {
    final people = watchedPeople(
      const ZoneSettings(),
      [
        contact('1', favourite: true, lat: lat0),
        contact('2', lat: lat0),
        contact('3', favourite: true),
      ],
      radio: (name: 'Me', lat: lat0, lon: lon0),
    );
    expect(people.map((p) => p.name), ['Me', 'C1']);
    expect(
      watchedPeople(
        const ZoneSettings(favouritesOnly: false, includeRadio: false),
        [contact('1', favourite: true, lat: lat0), contact('2', lat: lat0)],
      ).map((p) => p.name),
      ['C1', 'C2'],
    );
  });

  test('alert text in English and Spanish', () {
    const ZoneAlert a = (
      kind: ZoneAlertKind.left,
      key: 'k',
      name: 'Sam',
      zone: camp,
      metres: null,
    );
    expect(
      zoneAlertText(alertStrings(const Locale('en')), a).body,
      'Sam has left Camp.',
    );
    expect(
      zoneAlertText(alertStrings(const Locale('es')), a).body,
      'Sam ha salido de Camp.',
    );
    expect(alertStrings(const Locale('ja')).zoneOnBoth, 'Both');
  });
}
