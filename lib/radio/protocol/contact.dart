import 'dart:typed_data';

import 'codes.dart';
import 'public_key.dart';

/// A node in the radio's contact table, as the radio reports it.
final class RadioContact {
  RadioContact({
    required this.publicKey,
    required this.type,
    required this.flags,
    required this.outPathLength,
    required List<int> outPath,
    required this.name,
    required this.lastAdvert,
    required this.latitude,
    required this.longitude,
    required this.lastModified,
  }) : outPath = Uint8List.fromList(outPath);

  final PublicKey publicKey;
  final NodeType type;

  /// Firmware contact flags (bit 0 = favourite).
  final int flags;

  /// Encoded route length, or [pathUnknown] when the radio will flood.
  /// The low 6 bits are the hop count and the top 2 bits plus one give the
  /// bytes per hop.
  final int outPathLength;

  /// The stored route. Only the first [routeByteCount] bytes are meaningful.
  final Uint8List outPath;

  final String name;

  /// When the node last advertised, in Unix seconds by its own clock.
  final int lastAdvert;

  /// Advertised position in degrees, or null when the node shares none.
  final double? latitude;
  final double? longitude;

  /// When the radio last changed this entry, in Unix seconds by the radio's
  /// clock. Pass the newest value back to [CommandCode.getContacts] to fetch
  /// only what changed.
  final int lastModified;

  bool get hasRoute => outPathLength != pathUnknown;

  int get hopCount => hasRoute ? outPathLength & 0x3F : 0;

  int get bytesPerHop => hasRoute ? (outPathLength >> 6) + 1 : 0;

  int get routeByteCount => hopCount * bytesPerHop;

  Uint8List get route => Uint8List.sublistView(outPath, 0, routeByteCount);
}

/// Converts a firmware microdegree pair to degrees. The firmware stores
/// (0, 0) for "no position".
({double? latitude, double? longitude}) positionFromMicrodegrees(
  int lat,
  int lon,
) {
  if (lat == 0 && lon == 0) return (latitude: null, longitude: null);
  return (latitude: lat / 1e6, longitude: lon / 1e6);
}

int toMicrodegrees(double? degrees) =>
    degrees == null ? 0 : (degrees * 1e6).round();
