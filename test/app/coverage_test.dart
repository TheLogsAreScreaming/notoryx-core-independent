import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/coverage.dart';

void main() {
  const origin = LatLng(41.0, -73.0);

  test('nearby points share a hexagon; far ones do not', () {
    final a = hexOf(origin, origin);
    expect(a, (q: 0, r: 0));
    expect(hexOf(const LatLng(41.0005, -73.0005), origin), a);
    expect(hexOf(const LatLng(41.01, -73.0), origin), isNot(a));
  });

  test('a hexagon’s corners surround its centre point', () {
    final h = hexOf(const LatLng(41.02, -72.98), origin);
    final corners = hexCorners(h, origin);
    expect(corners, hasLength(6));
    final lat = corners.map((c) => c.latitude).reduce((a, b) => a + b) / 6;
    final lon = corners.map((c) => c.longitude).reduce((a, b) => a + b) / 6;
    expect(hexOf(LatLng(lat, lon), origin), h);
  });

  test('cells keep the best link, and can be limited to one repeater', () {
    final pings = [
      (at: origin, hits: [(repeater: 'r1', heardUs: 8.0, weHeard: 2.0)]),
      (at: origin, hits: [(repeater: 'r2', heardUs: 10.0, weHeard: 9.0)]),
      (
        at: const LatLng(41.05, -73.0),
        hits: const <({String repeater, double heardUs, double weHeard})>[],
      ),
    ];
    final all = coverageCells(pings, origin);
    expect(all, hasLength(2));
    final here = all.firstWhere((c) => c.hex == (q: 0, r: 0));
    expect(here.pings, 2);
    expect(here.best, 9.0);
    final r1 = coverageCells(pings, origin, repeater: 'r1');
    expect(r1.firstWhere((c) => c.hex == (q: 0, r: 0)).best, 2.0);
    expect(all.firstWhere((c) => c.hex != (q: 0, r: 0)).best, isNull);
  });

  test('radio horizon and Fresnel zone match the usual formulas', () {
    expect(radioHorizonKm(2, 10), closeTo(18.9, 0.1));
    expect(fresnelMetres(10, 915), closeTo(28.6, 0.2));
  });
}
