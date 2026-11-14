/// Area-limited channel messages ("flood corridor"): a channel post that
/// carries one or more circles, and repeaters outside every circle don't
/// pass it on.
///
/// Experimental: only firmware built from the flood-corridor branch of
/// MeshCore understands it. Stock firmware answers the commands with
/// "unsupported", and the app then sends normally.
library;

/// The radius sizes the firmware knows, by 4-bit code, in km. Code 15 is
/// "no limit" and isn't offered.
const areaRadiusKm = <double>[
  1, 2, 3, 5, 8, 12, 20, 30, 50, 80, 120, 200, 300, 500, 800, //
];

/// 50 km, the firmware's own default for a channel post.
const defaultAreaRadiusCode = 8;

/// The most circles one message can carry.
const maxAreaCircles = 8;

/// Repeaters that don't know their own position drop the post instead of
/// passing it on.
const areaFlagFailClosed = 0x01;

/// The last circle is the destination; the others are the way there.
const areaFlagDestination = 0x04;

/// One circle a message stays within.
class AreaCircle {
  const AreaCircle({
    required this.latitude,
    required this.longitude,
    this.radiusCode = defaultAreaRadiusCode,
  });

  final double latitude;
  final double longitude;

  /// Index into [areaRadiusKm].
  final int radiusCode;

  double get radiusKm => areaRadiusKm[radiusCode.clamp(0, 14)];

  /// The 4-byte word on the wire: 14 bits of latitude, 14 of longitude
  /// (each scaled over its full range) and 4 of radius code.
  int encode() {
    int scale(double v, double lo, double span) =>
        ((v - lo) / span * 16383 + 0.5).floor().clamp(0, 16383);
    final lat = scale(latitude.clamp(-90, 90), -90, 180);
    final lon = scale(longitude.clamp(-180, 180), -180, 360);
    return (lat << 18) | (lon << 4) | (radiusCode.clamp(0, 14) & 0x0F);
  }

  static AreaCircle decode(int word) => AreaCircle(
    latitude: ((word >> 18) & 0x3FFF) / 16383 * 180 - 90,
    longitude: ((word >> 4) & 0x3FFF) / 16383 * 360 - 180,
    radiusCode: word & 0x0F,
  );
}
