import 'dart:convert';
import 'dart:math' as math;

/// LoRa bandwidths a MeshCore radio accepts, in kHz.
final _bandwidthsKhz = <double>{
  7.8,
  10.4,
  15.6,
  20.8,
  31.25,
  41.7,
  62.5,
  125.0,
  250.0,
  500.0,
};

/// The radio settings most nodes in one area use, from the shared
/// `regional_presets.json` list.
///
/// Areas with [source] `map` were worked out from what node owners report on
/// the public MeshCore map; the rest were added by hand by a local group.
class AreaPreset {
  const AreaPreset({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.frequencyMhz,
    required this.bandwidthKhz,
    required this.spreadingFactor,
    required this.codingRate,
    required this.updated,
    this.pathHashBytes,
    this.notes = '',
    this.source,
    this.nodeCount,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final double frequencyMhz;
  final double bandwidthKhz;
  final int spreadingFactor;

  /// 5 to 8, meaning 4/5 to 4/8.
  final int codingRate;

  /// Bytes per path hop the area uses, when known.
  final int? pathHashBytes;

  /// When the area's settings last changed, as YYYY-MM-DD.
  final String updated;
  final String notes;
  final String? source;

  /// For map areas, how many nodes on the map use these settings.
  final int? nodeCount;

  bool get fromMap => source == 'map';

  /// Changes when the area changes its settings, so a "not now" lapses.
  String get signature =>
      '$id|$frequencyMhz|$bandwidthKhz|$spreadingFactor|$codingRate|$updated';

  /// "908.205 MHz · BW 62.5 · SF9 · CR 4/8"
  String get summary =>
      '${frequencyMhz.toStringAsFixed(3)} MHz · BW ${_trim(bandwidthKhz)} · '
      'SF$spreadingFactor · CR 4/$codingRate';

  /// Kilometres from this area's centre to a point.
  double distanceKm(double lat, double lon) =>
      _haversineKm(latitude, longitude, lat, lon);

  /// Readable lines for each setting the radio would change. Empty when the
  /// radio already matches.
  List<String> changesFrom(RadioSettings radio) => [
    if ((radio.frequencyMhz - frequencyMhz).abs() > 0.0005)
      'Frequency ${radio.frequencyMhz.toStringAsFixed(3)} → '
          '${frequencyMhz.toStringAsFixed(3)} MHz',
    if ((radio.bandwidthKhz - bandwidthKhz).abs() > 0.05)
      'Bandwidth ${_trim(radio.bandwidthKhz)} → ${_trim(bandwidthKhz)} kHz',
    if (radio.spreadingFactor != spreadingFactor)
      'Spreading factor ${radio.spreadingFactor} → $spreadingFactor',
    if (radio.codingRate != codingRate)
      'Coding rate 4/${radio.codingRate} → 4/$codingRate',
  ];

  /// One area from the document, or null when anything is missing or out of
  /// range.
  static AreaPreset? tryParse(Map<String, Object?> j) {
    try {
      final center = (j['center']! as List).cast<num>();
      final preset = AreaPreset(
        id: j['id']! as String,
        name: j['name']! as String,
        latitude: center[0].toDouble(),
        longitude: center[1].toDouble(),
        radiusKm: (j['radiusKm']! as num).toDouble(),
        frequencyMhz: (j['frequencyMHz']! as num).toDouble(),
        bandwidthKhz: (j['bandwidthKHz']! as num).toDouble(),
        spreadingFactor: (j['spreadingFactor']! as num).toInt(),
        codingRate: (j['codingRate']! as num).toInt(),
        pathHashBytes: (j['pathHashBytes'] as num?)?.toInt(),
        updated: j['updated']! as String,
        notes: j['notes'] as String? ?? '',
        source: j['source'] as String?,
        nodeCount: (j['nodes'] as num?)?.toInt(),
      );
      return preset._valid ? preset : null;
    } on Object {
      return null;
    }
  }

  bool get _valid =>
      id.isNotEmpty &&
      name.isNotEmpty &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      radiusKm > 0 &&
      frequencyMhz >= 137 &&
      frequencyMhz <= 2500 &&
      _bandwidthsKhz.contains(bandwidthKhz) &&
      spreadingFactor >= 5 &&
      spreadingFactor <= 12 &&
      codingRate >= 5 &&
      codingRate <= 8 &&
      (pathHashBytes == null || (pathHashBytes! >= 1 && pathHashBytes! <= 3)) &&
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(updated);
}

/// The LoRa settings a radio reports.
typedef RadioSettings = ({
  double frequencyMhz,
  double bandwidthKhz,
  int spreadingFactor,
  int codingRate,
});

/// Reads a `regional_presets.json` document, version 1 or 2, skipping bad
/// entries. Empty when the document can't be read or is a newer version.
List<AreaPreset> parseAreaPresets(String source) {
  try {
    final doc = jsonDecode(source);
    if (doc is! Map<String, Object?>) return const [];
    final version = doc['version'];
    if (version != 1 && version != 2) return const [];
    final regions = doc['regions'];
    if (regions is! List) return const [];
    return [
      for (final r in regions)
        if (r is Map<String, Object?>) ?AreaPreset.tryParse(r),
    ];
  } on FormatException {
    return const [];
  }
}

/// The area around a point, nearest centre first; null outside them all.
AreaPreset? areaAt(List<AreaPreset> areas, double lat, double lon) {
  AreaPreset? best;
  var bestKm = double.infinity;
  for (final a in areas) {
    final km = a.distanceKm(lat, lon);
    if (km <= a.radiusKm && km < bestKm) {
      best = a;
      bestKm = km;
    }
  }
  return best;
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * 6371 * math.asin(math.sqrt(a));
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
