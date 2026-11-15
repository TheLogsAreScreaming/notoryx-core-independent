/// The phone's compass, and the sums for pointing at a node.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// One compass reading: degrees clockwise from magnetic north, and the
/// sensor's accuracy from 0 (unreliable) to 3 (high).
typedef HeadingReading = ({double heading, int accuracy});

/// Where compass headings come from. Tests replace it.
abstract interface class CompassSource {
  /// Whether this device has a compass the app can read.
  Future<bool> available();

  /// Headings, about 20 a second, while listened to.
  Stream<HeadingReading> headings();

  /// Degrees east of true north that magnetic north lies at [at], or null
  /// when it can't be worked out.
  Future<double?> declination(LatLng at);
}

/// The Android rotation-vector compass; other platforms report none yet.
class DeviceCompass implements CompassSource {
  const DeviceCompass();

  static const _events = EventChannel('notoryx/heading');
  static const _methods = MethodChannel('notoryx/compass');

  @override
  Future<bool> available() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _methods.invokeMethod<bool>('available') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Stream<HeadingReading> headings() =>
      _events.receiveBroadcastStream().map((event) {
        final map = event as Map<Object?, Object?>;
        return (
          heading: (map['heading']! as num).toDouble(),
          accuracy: (map['accuracy'] as num?)?.toInt() ?? 2,
        );
      });

  @override
  Future<double?> declination(LatLng at) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _methods.invokeMethod<double>('declination', {
        'lat': at.latitude,
        'lon': at.longitude,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final compassSourceProvider = Provider<CompassSource>(
  (ref) => const DeviceCompass(),
);

/// Turns within this many degrees either side count as on target.
const onTargetDegrees = 10.0;

/// Initial bearing from [from] to [to], degrees clockwise from true north.
double bearingDegrees(LatLng from, LatLng to) {
  final lat1 = from.latitudeInRad, lat2 = to.latitudeInRad;
  final dLon = to.longitudeInRad - from.longitudeInRad;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return normaliseDegrees(math.atan2(y, x) * 180 / math.pi);
}

/// [degrees] brought into 0 (inclusive) to 360 (exclusive).
double normaliseDegrees(double degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}

/// How far to turn from facing [heading] to face [bearing]: negative is
/// left, positive is right, never more than 180 either way.
double turnDegrees(double heading, double bearing) {
  final d = normaliseDegrees(bearing - heading);
  return d > 180 ? d - 360 : d;
}

/// Moves [previous] a [factor] of the way towards [next], the short way
/// round, so 359° to 1° passes through 0° rather than 180°.
double smoothHeading(double? previous, double next, {double factor = 0.25}) {
  if (previous == null) return normaliseDegrees(next);
  return normaliseDegrees(previous + turnDegrees(previous, next) * factor);
}

/// Which of the eight compass points [degrees] is nearest, as an index
/// from 0 (north) clockwise to 7 (north-west).
int compassPointIndex(double degrees) =>
    ((normaliseDegrees(degrees) + 22.5) ~/ 45) % 8;
