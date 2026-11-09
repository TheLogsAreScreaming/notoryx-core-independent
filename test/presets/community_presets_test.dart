import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/presets/community_presets.dart';

void main() {
  final all = parseCommunityPresets(
    File('assets/community_presets.json').readAsStringSync(),
  );

  test('the bundled list parses completely', () {
    expect(all, hasLength(27));
    final usa = all.firstWhere((p) => p.name == 'USA');
    expect(usa.frequencyMhz, 910.525);
    expect(usa.bandwidthKhz, 62.5);
    expect(usa.spreadingFactor, 7);
    expect(usa.codingRate, 5);
    expect(usa.pathHashBytes, isNull);
    expect(all.firstWhere((p) => p.name == 'Canada').pathHashBytes, 3);
  });

  test('your country comes first', () {
    expect(sortCommunityPresets(all, country: 'US').first.name, 'USA');
    expect(
      sortCommunityPresets(all, country: 'DE').first.name,
      'EU/UK (Narrow)',
    );
    expect(sortCommunityPresets(all, country: 'NL').first.name, 'Netherlands');
  });

  test('deprecated ones sink within your country', () {
    final vn = sortCommunityPresets(all, country: 'VN');
    expect(vn[0].name, 'Vietnam (Narrow)');
    expect(vn[1].name, 'Vietnam (Deprecated)');
  });

  test('no country, or an unlisted one, keeps the list usable', () {
    expect(sortCommunityPresets(all), hasLength(27));
    expect(sortCommunityPresets(all, country: 'ZZ'), hasLength(27));
  });

  test('search narrows it', () {
    expect(
      sortCommunityPresets(
        all,
        query: 'austral',
      ).every((p) => p.name.contains('Australia')),
      isTrue,
    );
    expect(sortCommunityPresets(all, query: 'nowhere'), isEmpty);
  });
}
