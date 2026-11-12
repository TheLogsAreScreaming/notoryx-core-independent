/// Path graph and route intelligence: every repeater path heard on flooded
/// packets, which repeaters this radio hears directly, and the chains of
/// repeaters behind each.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../radio/protocol/packet_header.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'safety.dart';

/// A path as stored: hop hashes in hex, oldest first, joined by '>'.
String pathKey(List<String> hops) => hops.join('>');

List<String> pathHops(String key) => key.isEmpty ? const [] : key.split('>');

/// A repeater this radio hears directly: the last hop of heard paths.
typedef DirectRepeater = ({
  String hash,
  int heard,
  double? averageSnr,
  List<HeardPathRow> paths,
});

/// Groups [paths] by their last hop, most heard first.
List<DirectRepeater> directRepeaters(List<HeardPathRow> paths) {
  final groups = <String, List<HeardPathRow>>{};
  for (final p in paths) {
    final hops = pathHops(p.hops);
    if (hops.isEmpty) continue;
    (groups[hops.last] ??= []).add(p);
  }
  final out = <DirectRepeater>[
    for (final MapEntry(key: hash, value: list) in groups.entries)
      () {
        var total = 0;
        var snrSum = 0.0;
        var snrCount = 0;
        for (final p in list) {
          total += p.count;
          if (p.lastSnr case final snr?) {
            snrSum += snr * p.count;
            snrCount += p.count;
          }
        }
        return (
          hash: hash,
          heard: total,
          averageSnr: snrCount == 0 ? null : snrSum / snrCount,
          paths: [...list]..sort((a, b) => b.count.compareTo(a.count)),
        );
      }(),
  ];
  return out..sort((a, b) => b.heard.compareTo(a.heard));
}

/// The name for hop [hash] among [repeaters] (name and full key). Short
/// hashes can match several; then they're all listed.
String hopName(
  String hash,
  Iterable<({String name, String publicKey})> repeaters,
) {
  final matches = {
    for (final r in repeaters)
      if (r.publicKey.toLowerCase().startsWith(hash.toLowerCase())) r.name,
  };
  return switch (matches.length) {
    0 => hash.toUpperCase(),
    1 => matches.first,
    _ => '${hash.toUpperCase()} (${matches.join(' or ')})',
  };
}

/// Records paths from flooded packets while a radio is connected.
final pathRecorderProvider = Provider<void>((ref) {
  final state = ref.watch(connectionProvider);
  if (state is! Connected) return;
  final db = ref.read(databaseProvider);
  final key = state.radio.key;
  final sub = state.sync.heard.listen((rx) async {
    final header = PacketHeader.parse(rx.packet);
    if (header == null || header.hopCount == 0) return;
    if (header.route != RouteKind.flood &&
        header.route != RouteKind.transportFlood) {
      return;
    }
    final hops = pathKey(header.hops);
    final now = ref.read(safetyClockProvider)().millisecondsSinceEpoch;
    try {
      await db.customStatement(
        'INSERT INTO heard_paths '
        '(radio_key, hops, hash_bytes, count, last_snr, last_at) '
        'VALUES (?, ?, ?, 1, ?, ?) '
        'ON CONFLICT(radio_key, hops) DO UPDATE SET '
        'count = count + 1, last_snr = excluded.last_snr, '
        'last_at = excluded.last_at',
        [key, hops, header.hashBytes, rx.snr, now],
      );
      db.notifyUpdates({TableUpdate.onTable(db.heardPaths)});
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('path graph: $e');
    }
  });
  ref.onDispose(sub.cancel);
});

final heardPathsProvider = StreamProvider.family<List<HeardPathRow>, String>((
  ref,
  radioKey,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.heardPaths,
  )..where((p) => p.radioKey.equals(radioKey))).watch();
});

Future<void> clearHeardPaths(MeshDatabase db, String radioKey) =>
    (db.delete(db.heardPaths)..where((p) => p.radioKey.equals(radioKey))).go();
