import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/range_rings.dart';

void main() {
  const metric = DistanceUnit.metric;
  const imperial = DistanceUnit.imperial;

  group('niceStep', () {
    test('rounds down to 1, 2 or 5 × 10ⁿ metres', () {
      expect(niceStep(10, metric), 10);
      expect(niceStep(19.9, metric), 10);
      expect(niceStep(20, metric), 20);
      expect(niceStep(49, metric), 20);
      expect(niceStep(50, metric), 50);
      expect(niceStep(99, metric), 50);
      expect(niceStep(100, metric), 100);
      expect(niceStep(1000, metric), 1000);
      expect(niceStep(10000, metric), 10000);
      expect(niceStep(1e6, metric), 1e6);
      expect(niceStep(740, metric), 500);
      expect(niceStep(1999, metric), 1000);
      expect(niceStep(2000, metric), 2000);
      expect(niceStep(123456, metric), 100000);
    });

    test('never below 10 m', () {
      expect(niceStep(3, metric), 10);
      expect(niceStep(0, metric), 10);
      expect(niceStep(-1, metric), 10);
      expect(niceStep(double.nan, metric), 10);
    });

    test('imperial steps are in miles, from 0.1 mi', () {
      expect(niceStep(10, imperial), closeTo(0.1 * metresPerMile, 1e-6));
      expect(
        niceStep(0.25 * metresPerMile, imperial),
        closeTo(0.2 * metresPerMile, 1e-6),
      );
      expect(
        niceStep(0.5 * metresPerMile, imperial),
        closeTo(0.5 * metresPerMile, 1e-6),
      );
      expect(
        niceStep(1 * metresPerMile, imperial),
        closeTo(1 * metresPerMile, 1e-6),
      );
      expect(
        niceStep(3.7 * metresPerMile, imperial),
        closeTo(2 * metresPerMile, 1e-6),
      );
      expect(
        niceStep(60 * metresPerMile, imperial),
        closeTo(50 * metresPerMile, 1e-6),
      );
    });
  });

  group('ringRadii', () {
    test('four rings, the reach divided by four and rounded down', () {
      // 4 km to the nearer edge: 1 km steps.
      expect(ringRadii(4000, metric), [1000, 2000, 3000, 4000]);
      // 3 km: 750 m rounds down to 500 m.
      expect(ringRadii(3000, metric), [500, 1000, 1500, 2000]);
    });

    test('the outer ring always fits inside the view', () {
      for (final reach in <double>[45, 333, 1234, 9876, 54321, 765432]) {
        for (final unit in DistanceUnit.values) {
          final radii = ringRadii(reach, unit);
          expect(radii, hasLength(4));
          if (reach >= 40 && unit == metric) {
            expect(radii.last, lessThanOrEqualTo(reach), reason: '$reach');
          }
        }
      }
    });

    test('a tiny view still gets the smallest step', () {
      expect(ringRadii(5, metric), [10, 20, 30, 40]);
    });
  });

  group('ringLabel', () {
    test('metres under a kilometre, then km', () {
      expect(ringLabel(10, metric), '10 m');
      expect(ringLabel(500, metric), '500 m');
      expect(ringLabel(1000, metric), '1 km');
      expect(ringLabel(1500, metric), '1.5 km');
      expect(ringLabel(20000, metric), '20 km');
    });

    test('miles with one decimal when needed', () {
      expect(ringLabel(0.1 * metresPerMile, imperial), '0.1 mi');
      expect(ringLabel(0.3 * metresPerMile, imperial), '0.3 mi');
      expect(ringLabel(2 * metresPerMile, imperial), '2 mi');
      expect(ringLabel(7.5 * metresPerMile, imperial), '7.5 mi');
    });
  });

  group('pointAt', () {
    const origin = LatLng(51.5, -0.12);

    test('zero distance stays put', () {
      final p = pointAt(origin, 0, 123);
      expect(p.latitude, closeTo(origin.latitude, 1e-9));
      expect(p.longitude, closeTo(origin.longitude, 1e-9));
    });

    test('due north moves only the latitude, by the arc length', () {
      // 1° of latitude is about 111.2 km on the mean-radius sphere.
      final p = pointAt(const LatLng(0, 0), 111195, 0);
      expect(p.latitude, closeTo(1, 1e-3));
      expect(p.longitude, closeTo(0, 1e-9));
    });

    test('east, south and west on the equator', () {
      final e = pointAt(const LatLng(0, 10), 111195, 90);
      expect(e.latitude, closeTo(0, 1e-9));
      expect(e.longitude, closeTo(11, 1e-3));
      final s = pointAt(const LatLng(0, 10), 111195, 180);
      expect(s.latitude, closeTo(-1, 1e-3));
      final w = pointAt(const LatLng(0, 10), 111195, 270);
      expect(w.longitude, closeTo(9, 1e-3));
    });

    test('the distance back matches the distance asked for', () {
      for (final bearing in <double>[0, 45, 90, 135, 180, 225, 270, 315]) {
        final p = pointAt(origin, 5000, bearing);
        expect(metresBetween(origin, p), closeTo(5000, 0.01));
      }
    });

    test('wraps across the date line', () {
      final p = pointAt(const LatLng(0, 179.9), 50000, 90);
      expect(p.longitude, lessThan(-179));
    });
  });

  test('viewReach is the distance to the nearer edge', () {
    // Wider than tall: the north and south edges are nearer.
    final reach = viewReach(
      const LatLng(0, 0),
      north: 0.01,
      south: -0.01,
      east: 0.05,
      west: -0.05,
    );
    expect(reach, closeTo(1112, 1));
  });

  test('miles where the roads use them, metres elsewhere', () {
    expect(distanceUnitFor(const Locale('en', 'US')), imperial);
    expect(distanceUnitFor(const Locale('en', 'GB')), imperial);
    expect(distanceUnitFor(const Locale('en', 'AU')), metric);
    expect(distanceUnitFor(const Locale('de', 'DE')), metric);
    expect(distanceUnitFor(const Locale('en')), metric);
  });
}
