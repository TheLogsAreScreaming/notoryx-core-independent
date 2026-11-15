/// Ground heights along a radio path, and how clear the direct line and
/// its first Fresnel zone are.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Speed of light in m/s.
const _lightSpeed = 299792458.0;

/// Mean earth radius in metres.
const _earthRadius = 6371000.0;

/// Radio waves bend a little with the air, so paths are worked out on an
/// earth 4/3 bigger than it is.
const _kFactor = 4 / 3;

/// Frequency to assume when the radio hasn't said which it uses.
const defaultFresnelMhz = 915.0;

/// Fraction of the first Fresnel zone that should stay clear of the ground.
const fresnelGoodRatio = 0.6;

/// Fresnel radii below this many metres are too thin to judge, so the
/// samples right at the antennas are left out.
const _minRadius = 0.5;

/// How many points along the path to ask the ground height for.
const terrainSamples = 64;

/// Radius in metres of the first Fresnel zone at a point [d1] metres from
/// one end and [d2] metres from the other, at [mhz]. Zero at the ends.
double fresnelRadius({
  required double d1,
  required double d2,
  required double mhz,
}) {
  if (d1 <= 0 || d2 <= 0 || mhz <= 0) return 0;
  final wavelength = _lightSpeed / (mhz * 1e6);
  return math.sqrt(wavelength * d1 * d2 / (d1 + d2));
}

/// How far the curve of the earth lifts the ground into the path at a
/// point [d1] and [d2] metres from the ends, in metres.
double earthBulge(double d1, double d2) =>
    d1 * d2 / (2 * _kFactor * _earthRadius);

/// One point along the path, all heights in metres above sea level.
typedef ProfileSample = ({
  double distance,
  double ground,
  double beam,
  double fresnel,
});

/// How the Fresnel zone fares at its tightest point.
enum FresnelVerdict {
  /// 60% or more of the zone is clear everywhere.
  clear,

  /// The direct line is clear but less than 60% of the zone is.
  partial,

  /// The ground reaches the direct line.
  blocked,
}

/// A worked-out path.
class PathProfile {
  const PathProfile({
    required this.samples,
    required this.lineOfSightClear,
    required this.worstRatio,
  });

  /// Every point, from your end to the other.
  final List<ProfileSample> samples;

  /// Whether the direct line clears the ground everywhere between the ends.
  final bool lineOfSightClear;

  /// The smallest clearance divided by the Fresnel radius over the inside
  /// points; 1 is fully clear, 0 touches the direct line, below 0 cuts it.
  /// Null when the path is too short to judge.
  final double? worstRatio;

  /// The worst clearance as a whole percent of the Fresnel radius.
  int get worstPercent => ((worstRatio ?? 1) * 100).round();

  FresnelVerdict get verdict {
    final ratio = worstRatio ?? 1;
    if (ratio < 0 || !lineOfSightClear) return FresnelVerdict.blocked;
    return ratio >= fresnelGoodRatio
        ? FresnelVerdict.clear
        : FresnelVerdict.partial;
  }
}

/// Works out a path [totalMetres] long from evenly spaced ground
/// [elevations] (first at your end, last at the other) with antennas
/// [startHeight] and [endHeight] metres above the ground at each end.
PathProfile analyseProfile({
  required List<double> elevations,
  required double totalMetres,
  required double startHeight,
  required double endHeight,
  required double mhz,
}) {
  final n = elevations.length;
  if (n < 2) {
    return const PathProfile(
      samples: [],
      lineOfSightClear: true,
      worstRatio: null,
    );
  }
  final start = elevations.first + startHeight;
  final end = elevations.last + endHeight;
  final samples = <ProfileSample>[];
  var clear = true;
  double? worst;
  for (var i = 0; i < n; i++) {
    final d1 = totalMetres * i / (n - 1);
    final d2 = totalMetres - d1;
    final ground = elevations[i] + earthBulge(d1, d2);
    final beam = start + (end - start) * i / (n - 1);
    final r = fresnelRadius(d1: d1, d2: d2, mhz: mhz);
    samples.add((distance: d1, ground: ground, beam: beam, fresnel: r));
    if (i == 0 || i == n - 1) continue;
    final clearance = beam - ground;
    if (clearance < 0) clear = false;
    if (r < _minRadius) continue;
    final ratio = clearance / r;
    if (worst == null || ratio < worst) worst = ratio;
  }
  return PathProfile(
    samples: samples,
    lineOfSightClear: clear,
    worstRatio: worst,
  );
}

/// [count] evenly spaced points from [a] to [b], both ends included.
List<LatLng> pathPoints(LatLng a, LatLng b, int count) => [
  for (var i = 0; i < count; i++)
    LatLng(
      a.latitude + (b.latitude - a.latitude) * i / (count - 1),
      a.longitude + (b.longitude - a.longitude) * i / (count - 1),
    ),
];

/// Looks up the ground height of each point in metres, or null when it
/// can't. Tests replace this.
final elevationLookupProvider =
    Provider<Future<List<double>?> Function(List<LatLng> points)>(
      (ref) => openMeteoElevations,
    );

/// Ground heights from the free Open-Meteo elevation service, which takes
/// up to 100 points at a time.
Future<List<double>?> openMeteoElevations(List<LatLng> points) async {
  if (points.isEmpty || points.length > 100) return null;
  String list(double Function(LatLng) pick) =>
      points.map((p) => pick(p).toStringAsFixed(5)).join(',');
  final uri = Uri.https('api.open-meteo.com', '/v1/elevation', {
    'latitude': list((p) => p.latitude),
    'longitude': list((p) => p.longitude),
  });
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final body = await response.transform(utf8.decoder).join();
    return parseElevations(jsonDecode(body), points.length);
  } on Object {
    return null;
  } finally {
    client.close();
  }
}

/// The heights in an Open-Meteo reply, or null if it isn't [count] numbers.
List<double>? parseElevations(Object? reply, int count) {
  if (reply is! Map) return null;
  final list = reply['elevation'];
  if (list is! List || list.length != count) return null;
  final out = <double>[];
  for (final v in list) {
    if (v is! num) return null;
    out.add(v.toDouble());
  }
  return out;
}
