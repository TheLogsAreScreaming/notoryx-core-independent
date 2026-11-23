/// Status replies and neighbour signal kept over time, for charts.
library;

import 'dart:convert';

import '../data/data.dart';
import '../radio/radio.dart';
import 'repeater_tools.dart';
import 'telemetry.dart' show TelemetryPoint;

/// One status reply, reduced to the values worth charting.
typedef ServerCheck = ({
  DateTime at,
  int batteryMv,
  int rssi,
  double snr,
  int noiseFloor,
  int errors,
  int upSeconds,
});

/// The values a status chart can show.
enum ServerValue { battery, rssi, snr, noiseFloor, errors, upTime }

double serverValue(ServerCheck c, ServerValue v) => switch (v) {
  ServerValue.battery => c.batteryMv / 1000,
  ServerValue.rssi => c.rssi.toDouble(),
  ServerValue.snr => c.snr,
  ServerValue.noiseFloor => c.noiseFloor.toDouble(),
  ServerValue.errors => c.errors.toDouble(),
  ServerValue.upTime => c.upSeconds / 3600,
};

/// How long and how many status replies are kept per server.
const serverHistoryKeep = Duration(days: 30);
const serverHistoryMax = 400;

String _key(String radioKey, String nodeKey) =>
    'server_status_v1:$radioKey:$nodeKey';

List<num> _encode(ServerCheck c) => [
  c.at.millisecondsSinceEpoch,
  c.batteryMv,
  c.rssi,
  c.snr,
  c.noiseFloor,
  c.errors,
  c.upSeconds,
];

ServerCheck? _decode(Object? e) {
  if (e is! List || e.length != 7 || e.any((v) => v is! num)) return null;
  final n = e.cast<num>();
  return (
    at: DateTime.fromMillisecondsSinceEpoch(n[0].toInt()),
    batteryMv: n[1].toInt(),
    rssi: n[2].toInt(),
    snr: n[3].toDouble(),
    noiseFloor: n[4].toInt(),
    errors: n[5].toInt(),
    upSeconds: n[6].toInt(),
  );
}

/// The status replies kept for [nodeKey] on [radioKey], oldest first.
Future<List<ServerCheck>> loadServerChecks(
  MeshStore store,
  String radioKey,
  String nodeKey,
) async {
  final raw = await store.setting(_key(radioKey, nodeKey));
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return [for (final e in list) ?_decode(e)];
  } on FormatException {
    return const [];
  }
}

/// Keeps [status], received at [at], and drops what is too old or too many.
Future<void> keepServerCheck(
  MeshStore store,
  String radioKey,
  String nodeKey,
  ServerStatus status,
  DateTime at,
) async {
  final check = (
    at: at,
    batteryMv: status.batteryMillivolts,
    rssi: status.lastRssi,
    snr: status.lastSnr,
    noiseFloor: status.noiseFloor,
    errors: status.errorEvents,
    upSeconds: status.upTimeSeconds,
  );
  final cutoff = at.subtract(serverHistoryKeep);
  final all = [
    for (final c in await loadServerChecks(store, radioKey, nodeKey))
      if (!c.at.isBefore(cutoff)) c,
    check,
  ]..sort((a, b) => a.at.compareTo(b.at));
  final kept = all.length > serverHistoryMax
      ? all.sublist(all.length - serverHistoryMax)
      : all;
  await store.saveSetting(
    _key(radioKey, nodeKey),
    jsonEncode([for (final c in kept) _encode(c)]),
  );
}

/// How well the repeater heard the neighbour [prefix] each time the
/// `neighbors` command was answered in its console [lines], oldest first.
/// Each point is placed when the neighbour was last heard; one reading
/// reported again by a later reply is kept once.
List<TelemetryPoint> neighborSnrTrail(List<Message> lines, String prefix) {
  final out = <TelemetryPoint>[];
  for (final m in lines) {
    if (m.outgoing) continue;
    final list = parseNeighbors(m.body);
    if (list == null) continue;
    for (final n in list) {
      if (n.prefix != prefix) continue;
      final at = DateTime.fromMillisecondsSinceEpoch(m.storedAt)
          .subtract(Duration(seconds: n.secondsAgo));
      final same = out.any(
        (p) => (p.at.difference(at).inSeconds).abs() < 90 && p.value == n.snr,
      );
      if (!same) out.add((at: at, value: n.snr));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
