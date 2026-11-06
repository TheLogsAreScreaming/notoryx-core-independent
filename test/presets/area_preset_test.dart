import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/presets/area_preset.dart';

Map<String, Object?> phoenix({Object? pathHash}) => {
  'id': 'map-908-205-62-5-sf9-33--112',
  'name': 'Phoenix, Arizona',
  'center': [33.45, -112.07],
  'radiusKm': 150,
  'frequencyMHz': 908.205,
  'bandwidthKHz': 62.5,
  'spreadingFactor': 9,
  'codingRate': 8,
  'pathHashBytes': ?pathHash,
  'updated': '2026-11-06',
  'source': 'map',
  'nodes': 219,
};

String doc(List<Map<String, Object?>> regions, {int version = 2}) =>
    jsonEncode({'version': version, 'regions': regions});

const usDefault = (
  frequencyMhz: 910.525,
  bandwidthKhz: 62.5,
  spreadingFactor: 7,
  codingRate: 5,
);

void main() {
  test('reads a map area', () {
    final area = parseAreaPresets(doc([phoenix()])).single;
    expect(area.name, 'Phoenix, Arizona');
    expect(area.fromMap, isTrue);
    expect(area.nodeCount, 219);
    expect(area.pathHashBytes, isNull);
    expect(area.summary, '908.205 MHz · BW 62.5 · SF9 · CR 4/8');
  });

  test('skips bad entries and unknown versions', () {
    final bad = {...phoenix(), 'bandwidthKHz': 100};
    final noName = {...phoenix()}..remove('name');
    expect(parseAreaPresets(doc([phoenix(), bad, noName])), hasLength(1));
    expect(parseAreaPresets(doc([phoenix(pathHash: 4)])), isEmpty);
    expect(parseAreaPresets(doc([phoenix()], version: 3)), isEmpty);
    expect(parseAreaPresets('not json'), isEmpty);
    expect(parseAreaPresets('[]'), isEmpty);
  });

  test('version 1 files still work', () {
    final area = parseAreaPresets(doc([phoenix(pathHash: 2)], version: 1))
        .single;
    expect(area.pathHashBytes, 2);
  });

  test('finds the area around a point, nearest centre first', () {
    final wide = {
      ...phoenix(),
      'id': 'wide',
      'name': 'Wide',
      'center': [34.5, -112.5],
      'radiusKm': 300,
    };
    final areas = parseAreaPresets(doc([wide, phoenix()]));
    expect(areaAt(areas, 33.5, -112.0)?.name, 'Phoenix, Arizona');
    expect(areaAt(areas, 35.2, -112.4)?.name, 'Wide');
    expect(areaAt(areas, 40.7, -74.0), isNull);
  });

  test('lists what would change', () {
    final area = parseAreaPresets(doc([phoenix()])).single;
    expect(area.changesFrom(usDefault), [
      'Frequency 910.525 → 908.205 MHz',
      'Spreading factor 7 → 9',
      'Coding rate 4/5 → 4/8',
    ]);
    expect(
      area.changesFrom((
        frequencyMhz: 908.205,
        bandwidthKhz: 62.5,
        spreadingFactor: 9,
        codingRate: 8,
      )),
      isEmpty,
    );
  });

  test('distance is in kilometres', () {
    final area = parseAreaPresets(doc([phoenix()])).single;
    // Phoenix to Tucson is about 170 km.
    expect(area.distanceKm(32.22, -110.97), closeTo(170, 10));
  });

  test('the bundled list is valid', () {
    final source = File('assets/regional_presets.json').readAsStringSync();
    final listed = (jsonDecode(source)['regions'] as List).length;
    final areas = parseAreaPresets(source);
    expect(areas, hasLength(listed));
    expect(areas.any((a) => a.frequencyMhz == 908.205), isTrue);
  });
}
