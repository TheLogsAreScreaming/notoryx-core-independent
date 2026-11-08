import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/mesh_links.dart';
import 'package:notoryx_core/app/shared_items.dart';

void main() {
  test('positions are found in shared text, SOS and check-ins', () {
    expect(positionText(const LatLng(46.5, -121.25)), '📍 46.50000,-121.25000');
    expect(
      sharedPosition('📍 46.50000,-121.25000'),
      const LatLng(46.5, -121.25),
    );
    expect(
      sharedPosition('SOS - I need help. Position 46.50000,-121.25000'),
      const LatLng(46.5, -121.25),
    );
    expect(
      sharedPosition('at 12.5, 3.25 maybe'),
      isNull,
      reason: 'too few digits',
    );
    // Any coordinate-shaped pair counts; a false match only adds a map chip.
    expect(sharedPosition('version 1.2345,6.7890'), isNotNull);
    expect(sharedPosition('99.12345,10.12345'), isNull, reason: 'out of range');
    expect(sharedPosition('no numbers here'), isNull);
  });

  test('links are found in text', () {
    final url = ChannelLink(
      name: '#hiking',
      secret: hashtagSecret('#hiking'),
    ).url;
    expect(sharedLink('join $url please'), isA<ChannelLink>());
    expect(sharedLink('meshcore://nonsense'), isNull);
    expect(sharedLink('nothing'), isNull);
  });
}
