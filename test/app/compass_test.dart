import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/compass.dart';

void main() {
  test('bearingDegrees points the right way', () {
    const here = LatLng(40, -74);
    expect(bearingDegrees(here, const LatLng(41, -74)), closeTo(0, 0.01));
    expect(bearingDegrees(here, const LatLng(40, -73)), closeTo(90, 1));
    expect(bearingDegrees(here, const LatLng(39, -74)), closeTo(180, 0.01));
    expect(bearingDegrees(here, const LatLng(40, -75)), closeTo(270, 1));
  });

  test('turnDegrees takes the shorter way and signs left as negative', () {
    expect(turnDegrees(0, 90), 90);
    expect(turnDegrees(90, 0), -90);
    expect(turnDegrees(350, 10), 20);
    expect(turnDegrees(10, 350), -20);
    expect(turnDegrees(0, 180).abs(), 180);
  });

  test('smoothHeading goes the short way round past north', () {
    expect(smoothHeading(null, 365), closeTo(5, 1e-9));
    final next = smoothHeading(359, 1, factor: 0.5);
    expect(next, closeTo(0, 1e-9));
    final back = smoothHeading(1, 359, factor: 0.5);
    expect(back, closeTo(0, 1e-9));
    expect(smoothHeading(350, 10, factor: 0.25), closeTo(355, 1e-9));
  });

  test('compassPointIndex names the eight points', () {
    expect(compassPointIndex(0), 0);
    expect(compassPointIndex(359), 0);
    expect(compassPointIndex(44), 1);
    expect(compassPointIndex(90), 2);
    expect(compassPointIndex(225), 5);
    expect(compassPointIndex(315), 7);
    expect(compassPointIndex(-45), 7);
  });
}
