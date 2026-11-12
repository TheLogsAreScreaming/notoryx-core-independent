/// Wardriving: while moving, ping the repeaters within one hop and record
/// which answered, how well each way, and where the phone was.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../radio/protocol/discover.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'position.dart';
import 'safety.dart';

/// How long to wait for answers after each ping. Repeaters add a random
/// delay so they don't all answer at once.
const wardriveListen = Duration(seconds: 8);

const wardriveIntervals = [
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
];

/// A repeater that answered a ping.
typedef WardriveHit = ({
  String publicKey,
  double heardUs,
  double weHeard,
  int rssi,
});

/// Sends one discover ping and collects the answers.
Future<List<WardriveHit>> pingRepeaters(
  RadioSession session, {
  math.Random? random,
  Duration listen = wardriveListen,
}) async {
  final tag = (random ?? math.Random()).nextInt(0x7FFFFFFF) + 1;
  final hits = <String, WardriveHit>{};
  final sub = session.pushes.listen((p) {
    if (p is! ControlData) return;
    final a = parseDiscoverAnswer(p.payload);
    if (a == null || a.tag != tag) return;
    hits[a.publicKey] = (
      publicKey: a.publicKey,
      heardUs: a.heardUs,
      weHeard: p.snr,
      rssi: p.rssi,
    );
  });
  try {
    await session.run(SendControlData(discoverRequest(tag)));
    await Future<void>.delayed(listen);
  } finally {
    await sub.cancel();
  }
  return hits.values.toList();
}

/// The drive being recorded, or null.
final wardriveProvider = NotifierProvider<Wardrive, int?>(Wardrive.new);

class Wardrive extends Notifier<int?> {
  Timer? _timer;
  bool _busy = false;

  /// What the last ping found, for the screen.
  String? lastResult;

  @override
  int? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  MeshDatabase get _db => ref.read(databaseProvider);

  Future<void> start(Duration every) async {
    if (state != null) return;
    final now = ref.read(safetyClockProvider)();
    final id = await _db
        .into(_db.wardrives)
        .insert(
          WardrivesCompanion.insert(
            name:
                'Drive ${now.month}/${now.day} '
                '${now.hour.toString().padLeft(2, '0')}:'
                '${now.minute.toString().padLeft(2, '0')}',
            startedAt: now.millisecondsSinceEpoch,
          ),
        );
    state = id;
    _timer = Timer.periodic(every, (_) => unawaited(ping()));
    unawaited(ping());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final id = state;
    if (id == null) return;
    state = null;
    await (_db.update(_db.wardrives)..where((d) => d.id.equals(id))).write(
      WardrivesCompanion(
        endedAt: Value(ref.read(safetyClockProvider)().millisecondsSinceEpoch),
      ),
    );
  }

  /// One ping, stored with the phone's position. Skipped without a radio
  /// or a position, since a point with no place is no use on a map.
  Future<void> ping() async {
    final drive = state;
    final connection = ref.read(connectionProvider);
    if (drive == null || _busy || connection is! Connected) return;
    _busy = true;
    try {
      final here = await ref.read(phonePositionProvider)();
      if (here == null) {
        lastResult = 'No GPS position, so that ping was skipped.';
        ref.notifyListeners();
        return;
      }
      final hits = await pingRepeaters(connection.sync.session);
      final pingId = await _db
          .into(_db.wardrivePings)
          .insert(
            WardrivePingsCompanion.insert(
              drive: drive,
              at: ref.read(safetyClockProvider)().millisecondsSinceEpoch,
              latitude: here.latitude,
              longitude: here.longitude,
            ),
          );
      for (final h in hits) {
        await _db
            .into(_db.wardriveHits)
            .insert(
              WardriveHitsCompanion.insert(
                ping: pingId,
                repeaterKey: h.publicKey,
                heardUs: h.heardUs,
                weHeard: h.weHeard,
                rssi: h.rssi,
              ),
            );
      }
      lastResult = hits.isEmpty
          ? 'No repeater answered here.'
          : '${hits.length} repeater${hits.length == 1 ? '' : 's'} answered.';
      ref.notifyListeners();
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('wardrive ping: $e');
    } finally {
      _busy = false;
    }
  }
}

/// A ping and the best two-way signal it got, for the map.
typedef WardrivePoint = ({
  double latitude,
  double longitude,
  int answers,
  double? best,
});

/// The weaker direction of the best link, since a link is only as good as
/// its worse side.
double? bestLink(Iterable<({double heardUs, double weHeard})> hits) {
  double? best;
  for (final h in hits) {
    final link = math.min(h.heardUs, h.weHeard);
    if (best == null || link > best) best = link;
  }
  return best;
}

final wardrivePointsProvider = StreamProvider.family<List<WardrivePoint>, int>((
  ref,
  drive,
) {
  final db = ref.watch(databaseProvider);
  final pings = db.select(db.wardrivePings)
    ..where((p) => p.drive.equals(drive))
    ..orderBy([(p) => OrderingTerm.asc(p.id)]);
  return pings.watch().asyncMap((list) async {
    final out = <WardrivePoint>[];
    for (final p in list) {
      final hits = await (db.select(
        db.wardriveHits,
      )..where((h) => h.ping.equals(p.id))).get();
      out.add((
        latitude: p.latitude,
        longitude: p.longitude,
        answers: hits.length,
        best: bestLink([
          for (final h in hits) (heardUs: h.heardUs, weHeard: h.weHeard),
        ]),
      ));
    }
    return out;
  });
});

final wardrivesProvider = StreamProvider<List<WardriveRow>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.wardrives,
  )..orderBy([(d) => OrderingTerm.desc(d.id)])).watch();
});

/// Deletes drive [id] and everything recorded on it.
Future<void> deleteWardrive(
  MeshDatabase db,
  int id,
) => db.transaction(() async {
  final pings = await (db.select(
    db.wardrivePings,
  )..where((p) => p.drive.equals(id))).get();
  for (final p in pings) {
    await (db.delete(db.wardriveHits)..where((h) => h.ping.equals(p.id))).go();
  }
  await (db.delete(db.wardrivePings)..where((p) => p.drive.equals(id))).go();
  await (db.delete(db.wardrives)..where((d) => d.id.equals(id))).go();
});
