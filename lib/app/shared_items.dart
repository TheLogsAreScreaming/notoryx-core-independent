/// Positions and contact or channel links shared in chats, as plain text
/// so every app shows them.
library;

import 'package:latlong2/latlong.dart';

import 'mesh_links.dart';

/// The text that shares position [p].
String positionText(LatLng p) =>
    '📍 ${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

final _coordinates = RegExp(
  r'(?<![\d.])(-?\d{1,2}\.\d{3,}),\s?(-?\d{1,3}\.\d{3,})(?![\d.])',
);

/// The first position in [body], such as a shared 📍 or the position in an
/// SOS or check-in. Null when there is none or it's out of range.
LatLng? sharedPosition(String body) {
  final m = _coordinates.firstMatch(body);
  if (m == null) return null;
  final lat = double.parse(m.group(1)!);
  final lon = double.parse(m.group(2)!);
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return LatLng(lat, lon);
}

final _link = RegExp(r'meshcore://\S+');

/// The first `meshcore://` contact or channel link in [body].
MeshLink? sharedLink(String body) {
  final m = _link.firstMatch(body);
  return m == null ? null : MeshLink.parse(m.group(0)!);
}
