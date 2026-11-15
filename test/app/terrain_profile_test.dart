import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/terrain_profile.dart';

void main() {
  group('fresnelRadius', () {
    test('10 km at 915 MHz is about 28.6 m at the middle', () {
      final r = fresnelRadius(d1: 5000, d2: 5000, mhz: 915);
      expect(r, closeTo(28.6, 0.1));
    });

    test('is zero at the ends', () {
      expect(fresnelRadius(d1: 0, d2: 10000, mhz: 915), 0);
      expect(fresnelRadius(d1: 10000, d2: 0, mhz: 915), 0);
    });

    test('is narrower at a higher frequency', () {
      final low = fresnelRadius(d1: 5000, d2: 5000, mhz: 433);
      final mid = fresnelRadius(d1: 5000, d2: 5000, mhz: 915);
      final high = fresnelRadius(d1: 5000, d2: 5000, mhz: 2400);
      expect(low, greaterThan(mid));
      expect(mid, greaterThan(high));
    });
  });

  group('analyseProfile', () {
    List<double> flat([double height = 0]) =>
        List.filled(terrainSamples, height);

    test('high antennas over flat ground are Fresnel-clear', () {
      final p = analyseProfile(
        elevations: flat(),
        totalMetres: 10000,
        startHeight: 60,
        endHeight: 60,
        mhz: 915,
      );
      expect(p.lineOfSightClear, isTrue);
      expect(p.verdict, FresnelVerdict.clear);
      expect(p.worstPercent, greaterThanOrEqualTo(60));
    });

    test('a ridge can leave line of sight but not the Fresnel zone', () {
      final ground = flat();
      ground[terrainSamples ~/ 2] = 20;
      final p = analyseProfile(
        elevations: ground,
        totalMetres: 10000,
        startHeight: 30,
        endHeight: 30,
        mhz: 915,
      );
      expect(p.lineOfSightClear, isTrue);
      expect(p.verdict, FresnelVerdict.partial);
      expect(p.worstPercent, inInclusiveRange(0, 59));
    });

    test('a hill above the line blocks it', () {
      final ground = flat();
      ground[terrainSamples ~/ 2] = 80;
      final p = analyseProfile(
        elevations: ground,
        totalMetres: 10000,
        startHeight: 30,
        endHeight: 30,
        mhz: 915,
      );
      expect(p.lineOfSightClear, isFalse);
      expect(p.verdict, FresnelVerdict.blocked);
      expect(p.worstRatio, lessThan(0));
    });

    test('the beam runs from antenna top to antenna top', () {
      final ground = flat(100);
      final p = analyseProfile(
        elevations: ground,
        totalMetres: 2000,
        startHeight: 5,
        endHeight: 15,
        mhz: 915,
      );
      expect(p.samples.first.beam, 105);
      expect(p.samples.last.beam, 115);
      expect(p.samples.first.fresnel, 0);
      expect(p.samples.last.fresnel, 0);
    });

    test('too few heights gives an empty profile', () {
      final p = analyseProfile(
        elevations: const [1],
        totalMetres: 100,
        startHeight: 1,
        endHeight: 1,
        mhz: 915,
      );
      expect(p.samples, isEmpty);
      expect(p.worstRatio, isNull);
    });
  });

  test('pathPoints spaces points evenly with both ends', () {
    final pts = pathPoints(const LatLng(0, 0), const LatLng(1, 2), 3);
    expect(pts, hasLength(3));
    expect(pts[1].latitude, closeTo(0.5, 1e-9));
    expect(pts[1].longitude, closeTo(1, 1e-9));
    expect(pts.last, const LatLng(1, 2));
  });

  test('parseElevations accepts only a matching list of numbers', () {
    expect(
      parseElevations({
        'elevation': [1, 2.5],
      }, 2),
      [1.0, 2.5],
    );
    expect(
      parseElevations({
        'elevation': [1],
      }, 2),
      isNull,
    );
    expect(
      parseElevations({
        'elevation': ['x', 2],
      }, 2),
      isNull,
    );
    expect(parseElevations('nope', 1), isNull);
  });
}
