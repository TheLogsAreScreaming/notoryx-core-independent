/// The node journal: every node this radio hears is logged automatically,
/// with when, how well and where. From that history each node gets
/// behaviour labels (always-on repeater, roamer, rarely heard...), each with
/// a confidence and the evidence behind it. Users add their own tags and
/// a note. Every node also gets a generated mark, drawn from its key, so
/// the same node always looks the same.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'safety.dart';

/// Sightings kept per node; older ones are dropped.
const journalSightingsPerNode = 300;

/// A node heard again within this long counts once: a flood reaches this
/// radio through several repeaters in quick succession.
const journalRepeatWindow = Duration(seconds: 10);

/// Logs one hearing of a node. Adds the node on first hearing, keeps the
/// name and type current, and trims old sightings.
Future<void> recordSighting(
  MeshDatabase db,
  String radioKey, {
  required String nodeKey,
  required DateTime at,
  String? name,
  int? type,
  double? snr,
  int? hops,
  double? latitude,
  double? longitude,
}) async {
  final ms = at.millisecondsSinceEpoch;
  final key = nodeKey.toLowerCase();
  final placed =
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0) &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
  await db.transaction(() async {
    final existing =
        await (db.select(db.journalNodes)..where(
              (n) => n.radioKey.equals(radioKey) & n.nodeKey.equals(key),
            ))
            .getSingleOrNull();
    if (existing != null &&
        (ms - existing.lastHeard).abs() < journalRepeatWindow.inMilliseconds) {
      return;
    }
    if (existing == null) {
      await db
          .into(db.journalNodes)
          .insert(
            JournalNodesCompanion.insert(
              radioKey: radioKey,
              nodeKey: key,
              name: name ?? key.substring(0, math.min(8, key.length)),
              type: type ?? 0,
              firstHeard: ms,
              lastHeard: ms,
              heardCount: 1,
            ),
          );
    } else {
      await (db.update(db.journalNodes)
            ..where((n) => n.radioKey.equals(radioKey) & n.nodeKey.equals(key)))
          .write(
            JournalNodesCompanion(
              name: name == null ? const Value.absent() : Value(name),
              type: type == null || type == 0
                  ? const Value.absent()
                  : Value(type),
              firstHeard: Value(math.min(existing.firstHeard, ms)),
              lastHeard: Value(math.max(existing.lastHeard, ms)),
              heardCount: Value(existing.heardCount + 1),
            ),
          );
    }
    await db
        .into(db.journalSightings)
        .insert(
          JournalSightingsCompanion.insert(
            radioKey: radioKey,
            nodeKey: key,
            at: ms,
            snr: Value(snr),
            hops: Value(hops),
            latitude: Value(placed ? latitude : null),
            longitude: Value(placed ? longitude : null),
          ),
        );
    await db.customStatement(
      'DELETE FROM journal_sightings WHERE radio_key = ? AND node_key = ? '
      'AND id NOT IN (SELECT id FROM journal_sightings '
      'WHERE radio_key = ? AND node_key = ? ORDER BY at DESC LIMIT ?)',
      [radioKey, key, radioKey, key, journalSightingsPerNode],
    );
  });
}

/// Logs nodes from the adverts this radio hears while connected.
final journalRecorderProvider = Provider<void>((ref) {
  final state = ref.watch(connectionProvider);
  if (state is! Connected) return;
  final db = ref.read(databaseProvider);
  final radioKey = state.radio.key;
  final sub = state.sync.heard.listen((rx) async {
    final header = PacketHeader.parse(rx.packet);
    if (header == null || header.payload != PayloadKind.advert) return;
    final payload = Uint8List.sublistView(
      rx.packet,
      rx.packet.length - header.payloadLength,
    );
    final advert = parseAdvertPayload(payload);
    if (advert == null || advert.publicKey == radioKey) return;
    final direct =
        header.route == RouteKind.direct ||
        header.route == RouteKind.transportDirect;
    try {
      await recordSighting(
        db,
        radioKey,
        nodeKey: advert.publicKey,
        at: ref.read(safetyClockProvider)(),
        name: advert.name,
        type: advert.type,
        snr: rx.snr,
        hops: direct ? null : header.hopCount,
        latitude: advert.latitude,
        longitude: advert.longitude,
      );
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('node journal: $e');
    }
  });
  ref.onDispose(sub.cancel);
});

final journalNodesProvider = StreamProvider.family<List<JournalNode>, String>((
  ref,
  radioKey,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.journalNodes)
        ..where((n) => n.radioKey.equals(radioKey))
        ..orderBy([(n) => OrderingTerm.desc(n.lastHeard)]))
      .watch();
});

/// Sightings of one node, oldest first.
final journalSightingsProvider =
    StreamProvider.family<
      List<JournalSighting>,
      ({String radioKey, String nodeKey})
    >((ref, id) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.journalSightings)
            ..where(
              (s) =>
                  s.radioKey.equals(id.radioKey) & s.nodeKey.equals(id.nodeKey),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.at)]))
          .watch();
    });

/// Every sighting for [radioKey] since [since], grouped by node.
Future<Map<String, List<JournalSighting>>> sightingsSince(
  MeshDatabase db,
  String radioKey,
  DateTime since,
) async {
  final rows =
      await (db.select(db.journalSightings)
            ..where(
              (s) =>
                  s.radioKey.equals(radioKey) &
                  s.at.isBiggerOrEqualValue(since.millisecondsSinceEpoch),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.at)]))
          .get();
  final out = <String, List<JournalSighting>>{};
  for (final r in rows) {
    (out[r.nodeKey] ??= []).add(r);
  }
  return out;
}

/// Nodes with their labels, for the journal list. Recomputed when the
/// journal changes.
final journalSummariesProvider =
    StreamProvider.family<List<JournalSummary>, String>((ref, radioKey) async* {
      final db = ref.watch(databaseProvider);
      final clock = ref.watch(safetyClockProvider);
      final nodes =
          (db.select(db.journalNodes)
                ..where((n) => n.radioKey.equals(radioKey))
                ..orderBy([(n) => OrderingTerm.desc(n.lastHeard)]))
              .watch();
      await for (final list in nodes) {
        final now = clock();
        final sightings = await sightingsSince(
          db,
          radioKey,
          now.subtract(labelWindow),
        );
        yield [
          for (final n in list)
            (
              node: n,
              labels: describeNode(n, sightings[n.nodeKey] ?? const [], now),
            ),
        ];
      }
    });

typedef JournalSummary = ({JournalNode node, List<NodeLabel> labels});

/// Saves the user's [tags] and [note] for a node.
Future<void> saveJournalNotes(
  MeshDatabase db,
  String radioKey,
  String nodeKey, {
  List<String>? tags,
  String? note,
}) =>
    (db.update(db.journalNodes)..where(
          (n) => n.radioKey.equals(radioKey) & n.nodeKey.equals(nodeKey),
        ))
        .write(
          JournalNodesCompanion(
            tags: tags == null
                ? const Value.absent()
                : Value(cleanTags(tags).join('\n')),
            note: note == null ? const Value.absent() : Value(note.trim()),
          ),
        );

/// Removes a node and its history from the journal.
Future<void> forgetJournalNode(
  MeshDatabase db,
  String radioKey,
  String nodeKey,
) => db.transaction(() async {
  await (db.delete(db.journalSightings)
        ..where((s) => s.radioKey.equals(radioKey) & s.nodeKey.equals(nodeKey)))
      .go();
  await (db.delete(db.journalNodes)
        ..where((n) => n.radioKey.equals(radioKey) & n.nodeKey.equals(nodeKey)))
      .go();
});

/// Tags trimmed, without blanks or repeats (ignoring case), at most 24
/// characters each.
List<String> cleanTags(Iterable<String> tags) {
  final seen = <String>{};
  return [
    for (final t in tags)
      if (t.trim() case final tag
          when tag.isNotEmpty && seen.add(tag.toLowerCase()))
        tag.length > 24 ? tag.substring(0, 24) : tag,
  ];
}

List<String> tagsOf(JournalNode node) =>
    node.tags.isEmpty ? const [] : node.tags.split('\n');

// ---------------------------------------------------------------------------
// Behaviour labels.

/// How far back labels look.
const labelWindow = Duration(days: 30);

/// Labels below this confidence aren't shown.
const labelThreshold = 0.25;

enum NodeBehaviour {
  /// A repeater or room heard nearly every day, at short gaps.
  alwaysOn,

  /// Heard on most days, but not a fixed always-on node.
  regular,

  /// Reports positions far apart.
  roamer,

  /// Heard only now and then.
  rarelyHeard,

  /// First heard in the last two days.
  newArrival,

  /// Used to be heard often, silent for a week or more.
  goneQuiet,
}

/// One piece of evidence for a label, with the numbers it rests on. Shown
/// in words by the screen, so it can be translated.
sealed class Evidence {
  const Evidence();
}

/// Heard on [days] of the last [window] days.
final class HeardOnDays extends Evidence {
  const HeardOnDays(this.days, this.window);
  final int days;
  final int window;
}

/// Half the gaps between hearings are shorter than [hours].
final class TypicalGap extends Evidence {
  const TypicalGap(this.hours);
  final double hours;
}

/// It advertises itself as a repeater or room server.
final class IsInfrastructure extends Evidence {
  const IsInfrastructure();
}

/// Its reported positions are up to [km] apart, from [places] positions.
final class PositionSpread extends Evidence {
  const PositionSpread(this.km, this.places);
  final double km;
  final int places;
}

/// Heard [times] times in [days] days.
final class HeardTimes extends Evidence {
  const HeardTimes(this.times, this.days);
  final int times;
  final int days;
}

/// First heard [hours] hours ago.
final class FirstHeardAgo extends Evidence {
  const FirstHeardAgo(this.hours);
  final int hours;
}

/// Last heard [days] days ago.
final class LastHeardAgo extends Evidence {
  const LastHeardAgo(this.days);
  final int days;
}

/// A behaviour label with how sure it is (0 to 1) and why.
typedef NodeLabel = ({
  NodeBehaviour behaviour,
  double confidence,
  List<Evidence> evidence,
});

/// Labels [node] from its [sightings] (oldest first, within
/// [labelWindow]) as of [now]. Most confident first; only labels at
/// [labelThreshold] or more.
List<NodeLabel> describeNode(
  JournalNode node,
  List<JournalSighting> sightings,
  DateTime now,
) {
  final labels = <NodeLabel>[];
  final first = DateTime.fromMillisecondsSinceEpoch(node.firstHeard);
  final last = DateTime.fromMillisecondsSinceEpoch(node.lastHeard);
  final windowStart = now.subtract(labelWindow);
  final observedFrom = first.isAfter(windowStart) ? first : windowStart;
  final windowDays = math.max(
    1,
    _dayNumber(now) - _dayNumber(observedFrom) + 1,
  );
  final days = {for (final s in sightings) _dayNumber(_at(s))}.length;
  final dayShare = days / windowDays;
  final samples = math.min(1.0, sightings.length / 20);
  final type = NodeType.fromByte(node.type);
  final infrastructure = type == NodeType.repeater || type == NodeType.room;
  final sinceLast = now.difference(last);

  final gaps = [
    for (var i = 1; i < sightings.length; i++)
      sightings[i].at - sightings[i - 1].at,
  ]..sort();
  final medianGapHours = gaps.isEmpty
      ? null
      : gaps[gaps.length ~/ 2] / Duration.millisecondsPerHour;

  // Always-on: infrastructure, heard nearly every day at short gaps.
  if (infrastructure && windowDays >= 2 && medianGapHours != null) {
    final gapScore = (medianGapHours <= 6
        ? 1.0
        : math.max(0.0, 1 - (medianGapHours - 6) / 18));
    final quiet = sinceLast.inHours > 24 ? 0.5 : 1.0;
    final confidence =
        _clamp((dayShare - 0.5) * 2) * gapScore * samples * quiet;
    labels.add((
      behaviour: NodeBehaviour.alwaysOn,
      confidence: confidence,
      evidence: [
        const IsInfrastructure(),
        HeardOnDays(days, windowDays),
        TypicalGap(medianGapHours),
      ],
    ));
  }

  // Regular: most days, not an always-on node.
  if (!infrastructure && windowDays >= 3) {
    labels.add((
      behaviour: NodeBehaviour.regular,
      confidence: _clamp((dayShare - 0.4) / 0.4) * math.min(1, days / 5),
      evidence: [HeardOnDays(days, windowDays)],
    ));
  }

  // Roamer: positions spread out.
  final places = [
    for (final s in sightings)
      if (s.latitude != null && s.longitude != null)
        LatLng(s.latitude!, s.longitude!),
  ];
  if (places.length >= 2) {
    final km = _spreadKm(places);
    final distinct = {
      for (final p in places)
        '${p.latitude.toStringAsFixed(3)},${p.longitude.toStringAsFixed(3)}',
    }.length;
    if (km >= 0.5) {
      labels.add((
        behaviour: NodeBehaviour.roamer,
        confidence: _clamp(km / 5) * _clamp(distinct / 4),
        evidence: [PositionSpread(km, distinct)],
      ));
    }
  }

  // Rarely heard: few hearings over a long enough stretch.
  final spanDays = math.max(1, now.difference(first).inDays);
  if (spanDays >= 3) {
    final perWeek = sightings.length / math.min(spanDays, 30) * 7;
    labels.add((
      behaviour: NodeBehaviour.rarelyHeard,
      confidence: _clamp(1 - perWeek / 3) * _clamp(spanDays / 14),
      evidence: [
        HeardTimes(sightings.length, math.min(spanDays, 30)),
        if (sinceLast.inDays >= 1) LastHeardAgo(sinceLast.inDays),
      ],
    ));
  }

  // New arrival: first heard recently. Capped so behaviour labels win as
  // soon as there's history.
  final age = now.difference(first);
  if (age < const Duration(days: 2)) {
    labels.add((
      behaviour: NodeBehaviour.newArrival,
      confidence: 0.6 * (1 - age.inMinutes / const Duration(days: 2).inMinutes),
      evidence: [FirstHeardAgo(age.inHours)],
    ));
  }

  // Gone quiet: was heard on several days, nothing for a week.
  if (sinceLast.inDays >= 7 && node.heardCount >= 5) {
    labels.add((
      behaviour: NodeBehaviour.goneQuiet,
      confidence: _clamp(sinceLast.inDays / 14) * _clamp(node.heardCount / 20),
      evidence: [
        LastHeardAgo(sinceLast.inDays),
        HeardTimes(node.heardCount, math.max(1, last.difference(first).inDays)),
      ],
    ));
  }

  return labels.where((l) => l.confidence >= labelThreshold).toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
}

DateTime _at(JournalSighting s) => DateTime.fromMillisecondsSinceEpoch(s.at);

int _dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

double _clamp(num v) => v.toDouble().clamp(0.0, 1.0);

double _spreadKm(List<LatLng> places) {
  const distance = Distance();
  final sample = places.length > 60
      ? [for (var i = 0; i < places.length; i += places.length ~/ 60) places[i]]
      : places;
  var best = 0.0;
  for (var i = 0; i < sample.length; i++) {
    for (var j = i + 1; j < sample.length; j++) {
      best = math.max(best, distance(sample[i], sample[j]));
    }
  }
  return best / 1000;
}

// ---------------------------------------------------------------------------
// Generated marks.

/// A node's generated mark: a 5×5 grid mirrored left to right, and two
/// hues. The same key always gives the same mark.
typedef NodeMark = ({List<bool> cells, double hue, double accentHue});

/// The mark for [publicKey] (hex). Built from the SHA-256 of the key, so
/// nodes whose keys share a prefix still look different.
NodeMark nodeMark(String publicKey) {
  final hex = publicKey.toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');
  final bytes = sha256.convert(fromHex(hex.length.isEven ? hex : '0$hex'));
  final b = bytes.bytes;
  final cells = List.filled(25, false);
  var bit = 0;
  for (var row = 0; row < 5; row++) {
    for (var col = 0; col < 3; col++) {
      final on = (b[2 + bit ~/ 8] >> (bit % 8)) & 1 == 1;
      bit++;
      cells[row * 5 + col] = on;
      cells[row * 5 + (4 - col)] = on;
    }
  }
  // Never blank: light the middle column if nothing else is.
  if (!cells.contains(true)) {
    for (var row = 0; row < 5; row++) {
      cells[row * 5 + 2] = true;
    }
  }
  final hue = ((b[0] << 8) | b[1]) / 65536 * 360;
  return (cells: cells, hue: hue, accentHue: (hue + 150 + b[4] % 60) % 360);
}
