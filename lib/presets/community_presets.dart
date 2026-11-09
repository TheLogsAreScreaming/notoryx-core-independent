/// MeshCore's community radio presets, by country.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'area_preset.dart';

/// Reads the bundled list, skipping any entry that doesn't parse.
List<AreaPreset> parseCommunityPresets(String raw) {
  final json = jsonDecode(raw) as Map<String, Object?>;
  final fetched = json['fetched']! as String;
  final out = <AreaPreset>[];
  for (final item in json['presets']! as List<Object?>) {
    final m = item! as Map<String, Object?>;
    final title = m['title'] as String?;
    final mhz = double.tryParse('${m['frequency']}');
    final khz = double.tryParse('${m['bandwidth']}');
    final sf = int.tryParse('${m['spreading_factor']}');
    final cr = int.tryParse('${m['coding_rate']}');
    if (title == null ||
        mhz == null ||
        khz == null ||
        sf == null ||
        cr == null) {
      continue;
    }
    out.add(
      AreaPreset(
        id: 'community-$title',
        name: title,
        latitude: 0,
        longitude: 0,
        radiusKm: 0,
        frequencyMhz: mhz,
        bandwidthKhz: khz,
        spreadingFactor: sf,
        codingRate: cr,
        updated: fetched,
        pathHashBytes: m['path_hash_size'] as int?,
      ),
    );
  }
  return out;
}

final communityPresetsProvider = FutureProvider<List<AreaPreset>>(
  (ref) async => parseCommunityPresets(
    await rootBundle.loadString('assets/community_presets.json'),
  ),
);

/// Which preset titles fit each two-letter country code.
const _countryPrefixes = <String, String>{
  'US': 'USA',
  'CA': 'Canada',
  'AU': 'Australia',
  'NZ': 'New Zealand',
  'BR': 'Brazil',
  'CR': 'Costa Rica',
  'CZ': 'Czech',
  'HU': 'Hungary',
  'NL': 'Netherlands',
  'PT': 'Portugal',
  'SK': 'Slovakia',
  'CH': 'Switzerland',
  'TH': 'Thailand',
  'VN': 'Vietnam',
};

const _europe = {
  'GB', 'IE', 'DE', 'FR', 'ES', 'IT', 'BE', 'AT', 'PL', 'SE', 'NO', 'DK', //
  'FI', 'GR', 'RO', 'BG', 'HR', 'SI', 'LT', 'LV', 'EE', 'LU',
};

/// [presets] matching [query], those suited to [country] first. Otherwise
/// in the list's own order, with deprecated ones last in each group.
List<AreaPreset> sortCommunityPresets(
  List<AreaPreset> presets, {
  String? country,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final code = country?.toUpperCase();
  final prefix = _europe.contains(code) ? 'EU/UK' : _countryPrefixes[code];
  bool suits(AreaPreset p) => prefix != null && p.name.startsWith(prefix);
  bool old(AreaPreset p) => p.name.contains('Deprecated');
  int rank(AreaPreset p) => (suits(p) ? 0 : 2) + (old(p) ? 1 : 0);
  final matches = [
    for (final p in presets)
      if (q.isEmpty || p.name.toLowerCase().contains(q)) p,
  ];
  // List.sort isn't stable, so the original position breaks ties.
  final position = {for (final (i, p) in presets.indexed) p.id: i};
  return matches..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : position[a.id]!.compareTo(position[b.id]!);
  });
}
