/// Finding channels: suggestions for this area, a list of common public
/// hashtag channels, and which channels the radio has heard traffic on.
///
/// A channel message on air carries one byte that identifies its channel:
/// the first byte of SHA-256 of the channel's key. A hashtag channel's key
/// comes from its name, so for any name the app can tell whether that
/// channel has been heard, without being able to read it first. One byte
/// means different channels can share a code (1 in 256), so a match says
/// "probably".
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presets/area_preset.dart';
import '../radio/radio.dart';
import 'mesh_links.dart';
import 'packet_log.dart';

/// The code a channel's messages carry on air.
int channelCode(Uint8List secret) => sha256.convert(secret).bytes.first;

/// Common public hashtag channels, by theme. Whether one is used near you
/// shows up under "Heard on air".
const channelDirectory = <({String title, List<String> names})>[
  (title: 'Safety', names: ['#emergency', '#sar', '#weather']),
  (title: 'Getting started', names: ['#test', '#help', '#meshcore']),
  (
    title: 'Interests',
    names: ['#hiking', '#offgrid', '#ham', '#tech', '#news'],
  ),
];

/// How often a channel code was heard, and when last.
typedef HeardChannel = ({int count, DateTime last});

/// Channel codes heard in this session's packet log.
final heardChannelsProvider = Provider<Map<int, HeardChannel>>((ref) {
  final heard = <int, HeardChannel>{};
  for (final p in ref.watch(packetLogProvider)) {
    final code = p.header?.channelHash;
    if (code == null) continue;
    final before = heard[code];
    heard[code] = (
      count: (before?.count ?? 0) + 1,
      last: before == null || p.at.isAfter(before.last) ? p.at : before.last,
    );
  }
  return heard;
});

/// Hashtag channels to suggest for [area]: its name, and the place part of
/// its id (`us-phoenix` gives `#phoenix`).
List<String> localChannels(AreaPreset? area) {
  if (area == null) return const [];
  final names = <String>{hashtagName(area.name)};
  final place = area.id.split('-').skip(1).join('-');
  if (place.isNotEmpty) names.add(hashtagName(place));
  return names.toList();
}

/// The code of hashtag channel [name].
int hashtagCode(String name) => channelCode(hashtagSecret(name));

/// The suggested names (local first, then the directory) whose code
/// matches [code].
List<String> namesForCode(int code, Iterable<String> names) => [
  for (final n in names)
    if (hashtagCode(n) == code) n,
];

/// "AB" for a channel code.
String codeLabel(int code) => toHex([code]).toUpperCase();
