import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Finds the phone's own position. Tests replace this.
final phonePositionProvider = Provider<Future<LatLng?> Function()>(
  (ref) => () async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final p = await Geolocator.getCurrentPosition();
    return LatLng(p.latitude, p.longitude);
  },
);

/// The phone's position only if location is already allowed; never asks.
/// Tests replace this.
final allowedPhonePositionProvider = Provider<Future<LatLng?> Function()>(
  (ref) => () async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition();
      return LatLng(p.latitude, p.longitude);
    } on Object {
      return null;
    }
  },
);
