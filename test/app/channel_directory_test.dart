import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/channel_directory.dart';
import 'package:notoryx_core/app/mesh_links.dart';
import 'package:notoryx_core/presets/area_preset.dart';

void main() {
  test('a channel code is the first byte of SHA-256 of its key', () {
    // SHA-256 of 16 zero bytes starts 0x37.
    expect(channelCode(Uint8List(16)), 0x37);
    expect(hashtagCode('#hiking'), channelCode(hashtagSecret('#hiking')));
    expect(hashtagCode('Hiking'), hashtagCode('#hiking'));
  });

  test('names are matched to heard codes', () {
    final code = hashtagCode('#weather');
    expect(namesForCode(code, ['#test', '#weather']), ['#weather']);
    expect(codeLabel(0x0a), '0A');
  });

  test('local suggestions come from the area', () {
    const area = AreaPreset(
      id: 'us-phoenix',
      name: 'Phoenix',
      latitude: 33.45,
      longitude: -112.07,
      radiusKm: 120,
      frequencyMhz: 908.205,
      bandwidthKhz: 62.5,
      spreadingFactor: 9,
      codingRate: 5,
      updated: '2026-10-01',
    );
    expect(localChannels(area), ['#phoenix']);
    expect(localChannels(null), isEmpty);
  });
}
