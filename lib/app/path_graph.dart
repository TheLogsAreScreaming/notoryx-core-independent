/// Path graph and route intelligence: every repeater path heard on flooded
/// packets, which repeaters this radio hears directly, and the chains of
/// repeaters behind each.
library;

export 'hop_names.dart' show hopName;

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

/// Id of the middle of the network diagram: this radio.
const networkSelf = '';

/// Every heard path combined into rings around you: each repeater on the
/// ring for how many hops it most often is from you, links between
/// adjacent hops weighted by how many packets took them.
typedef PathNetwork = ({
  Map<String, ({int ring, int relayed})> nodes,
  Map<(String, String), int> links,
});

PathNetwork pathNetwork(List<HeardPathRow> paths, {int maxNodes = 40}) {
  final votes = <String, Map<int, int>>{};
  final relayed = <String, int>{};
  final links = <(String, String), int>{};
  for (final p in paths) {
    final hops = pathHops(p.hops);
    for (var i = 0; i < hops.length; i++) {
      final depth = hops.length - i;
      final v = votes[hops[i]] ??= {};
      v[depth] = (v[depth] ?? 0) + p.count;
      relayed[hops[i]] = (relayed[hops[i]] ?? 0) + p.count;
      final next = i + 1 < hops.length ? hops[i + 1] : networkSelf;
      links[(hops[i], next)] = (links[(hops[i], next)] ?? 0) + p.count;
    }
  }
  final keep =
      (relayed.keys.toList()
            ..sort((a, b) => relayed[b]!.compareTo(relayed[a]!)))
          .take(maxNodes)
          .toSet();
  return (
    nodes: {
      networkSelf: (ring: 0, relayed: 0),
      for (final id in keep)
        id: (
          ring: votes[id]!.entries
              .reduce((a, b) => b.value > a.value ? b : a)
              .key,
          relayed: relayed[id]!,
        ),
    },
    links: {
      for (final e in links.entries)
        if ((keep.contains(e.key.$1) || e.key.$1 == networkSelf) &&
            (keep.contains(e.key.$2) || e.key.$2 == networkSelf))
          e.key: e.value,
    },
  );
}
