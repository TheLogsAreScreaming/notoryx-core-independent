/// Distance rings around your own position on the map, spaced to suit
/// however far the map is zoomed out.
library;

import 'dart:math' as math;
import 'dart:ui' show Locale, Offset, Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'connection.dart';

/// Setting key; '1' when the rings are shown.
const rangeRingsKey = 'map.rangeRings';

/// How many rings are drawn.
const ringCount = 4;

/// Metres in an international mile.
const metresPerMile = 1609.344;

/// Mean earth radius in metres.
const _earthRadius = 6371008.8;

enum DistanceUnit { metric, imperial }

/// Miles for the places that still use them on the road; metres elsewhere.
DistanceUnit distanceUnitFor(Locale locale) =>
    const {'US', 'LR', 'MM', 'GB'}.contains(locale.countryCode)
    ? DistanceUnit.imperial
    : DistanceUnit.metric;

/// [metres] rounded down to 1, 2 or 5 × 10ⁿ in [unit], returned in metres.
///
/// The smallest step is 10 m, or 0.1 mi in imperial; anything below that
/// (or not a positive number) gets the smallest step.
double niceStep(double metres, DistanceUnit unit) {
  final imperial = unit == DistanceUnit.imperial;
  final perUnit = imperial ? metresPerMile : 1.0;
  final smallest = imperial ? 0.1 : 10.0;
  final value = metres / perUnit;
  if (!value.isFinite || value <= smallest) return smallest * perUnit;
  // A little slack so 1000 isn't read as 999.99… (and 2 as 1.99…), which
  // would round down a whole step.
  final power = math
      .pow(10, (math.log(value) / math.ln10 + 1e-9).floor())
      .toDouble();
  final leading = value / power + 1e-9;
  final digit = leading >= 5
      ? 5
      : leading >= 2
      ? 2
      : 1;
  return math.max(digit * power, smallest) * perUnit;
}

/// The [ringCount] ring radii, in metres, for a view whose centre is
/// [reach] metres from its nearer edge: the outer ring fits inside it.
List<double> ringRadii(double reach, DistanceUnit unit) {
  final step = niceStep(reach / ringCount, unit);
  return [for (var i = 1; i <= ringCount; i++) step * i];
}

/// "250 m", "1.5 km", "0.3 mi", "2 mi". Unit symbols aren't translated.
String ringLabel(double metres, DistanceUnit unit) {
  if (unit == DistanceUnit.imperial) {
    return '${_trim(metres / metresPerMile)} mi';
  }
  if (metres < 1000) return '${metres.round()} m';
  return '${_trim(metres / 1000)} km';
}

/// One decimal place at most, and none when it's a whole number.
String _trim(double value) {
  final tenths = (value * 10).round();
  return tenths % 10 == 0 ? '${tenths ~/ 10}' : (tenths / 10).toString();
}

/// The point [metres] from [from] heading [bearing] degrees clockwise from
/// true north, along a great circle.
LatLng pointAt(LatLng from, double metres, double bearing) {
  final d = metres / _earthRadius;
  final b = bearing * math.pi / 180;
  final lat1 = from.latitude * math.pi / 180;
  final lon1 = from.longitude * math.pi / 180;
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(b),
  );
  final lon2 =
      lon1 +
      math.atan2(
        math.sin(b) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2),
      );
  final lon = (lon2 * 180 / math.pi + 540) % 360 - 180;
  return LatLng(lat2 * 180 / math.pi, lon);
}

/// Great-circle distance between [a] and [b] in metres.
double metresBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLat = lat2 - lat1;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// Distance from [centre] of a view to its nearer edge, in metres, given the
/// view's [north], [south], [east] and [west] edges in degrees.
double viewReach(
  LatLng centre, {
  required double north,
  required double south,
  required double east,
  required double west,
}) {
  final toNorth = metresBetween(centre, LatLng(north, centre.longitude));
  final toSouth = metresBetween(centre, LatLng(south, centre.longitude));
  final toEast = metresBetween(centre, LatLng(centre.latitude, east));
  final toWest = metresBetween(centre, LatLng(centre.latitude, west));
  return [toNorth, toSouth, toEast, toWest].reduce(math.min);
}

/// How far out the compass letters sit, as a share of the outer ring.
const compassTagFactor = 1.12;

/// Room in pixels for the compass letter chips past [compassTagFactor].
const compassTagRoom = 14.0;

/// Pixels from [centre] to the nearest edge of the part of a [size] map
/// that nothing covers, after taking [left], [top], [right] and [bottom]
/// off its sides. Zero or less when [centre] is outside that part.
double clearRoom(
  Offset centre,
  Size size, {
  double left = 0,
  double top = 0,
  double right = 0,
  double bottom = 0,
}) => [
  centre.dx - left,
  centre.dy - top,
  size.width - right - centre.dx,
  size.height - bottom - centre.dy,
].reduce(math.min);

/// The largest outer-ring radius, in pixels, whose compass letters still
/// fit in [room] pixels: the letters sit at [compassTagFactor] × the outer
/// ring and need [compassTagRoom] more. Zero when there isn't room.
double ringRoomPx(double room) =>
    math.max(0, (room - compassTagRoom) / compassTagFactor);

/// Whether the map shows range rings. Saved on the phone, for every radio.
final rangeRingsProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(storeProvider)
      .watchSettingsWithPrefix(rangeRingsKey)
      .map((m) => m[''] == '1'),
);

Future<void> setRangeRings(WidgetRef ref, bool on) =>
    ref.read(storeProvider).saveSetting(rangeRingsKey, on ? '1' : '0');
