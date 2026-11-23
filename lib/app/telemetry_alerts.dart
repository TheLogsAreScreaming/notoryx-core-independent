/// Notices when a sensor value goes past a limit the person set.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'language.dart';
import 'notifications.dart';
import 'telemetry.dart';
import 'zone_alerts.dart' show alertStrings;

/// Upper and lower limits for one sensor value; either may be unset.
typedef TelemetryLimit = ({double? above, double? below});

bool limitIsEmpty(TelemetryLimit l) => l.above == null && l.below == null;

/// true when [v] is over the top, false when under the bottom, null inside.
bool? outsideLimit(TelemetryLimit l, double v) {
  if (l.above case final a? when v > a) return true;
  if (l.below case final b? when v < b) return false;
  return null;
}

String _prefix(String radioKey, String nodeKey) =>
    'telemetry_alert_v1:$radioKey:$nodeKey:';

/// The id of one value within a node: `channel:kind`.
String limitId(int channel, LppKind kind) => '$channel:${kind.name}';

TelemetryLimit? _decode(String? raw) {
  if (raw == null) return null;
  try {
    final m = jsonDecode(raw);
    if (m is! Map) return null;
    double? d(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    final l = (above: d(m['above']), below: d(m['below']));
    return limitIsEmpty(l) ? null : l;
  } on FormatException {
    return null;
  }
}

/// A node's limits by [limitId], as they change.
final telemetryLimitsProvider =
    StreamProvider.family<
      Map<String, TelemetryLimit>,
      ({String radioKey, String nodeKey})
    >(
      (ref, id) => ref
          .watch(storeProvider)
          .watchSettingsWithPrefix(_prefix(id.radioKey, id.nodeKey))
          .map(
            (m) => {
              for (final MapEntry(:key, :value) in m.entries)
                key: ?_decode(value),
            },
          ),
    );

/// Saves (or with null, removes) the limits for one value of a node.
Future<void> saveTelemetryLimit(
  MeshStore store, {
  required String radioKey,
  required String nodeKey,
  required String id,
  TelemetryLimit? limit,
}) {
  final key = '${_prefix(radioKey, nodeKey)}$id';
  if (limit == null || limitIsEmpty(limit)) return store.removeSetting(key);
  return store.saveSetting(
    key,
    jsonEncode({'above': ?limit.above, 'below': ?limit.below}),
  );
}

/// Decides which readings are worth a notification: only a step across a
/// limit (not every reading past it), and each value stays quiet for
/// [quiet] after it alerted.
class LimitJudge {
  LimitJudge({this.quiet = const Duration(minutes: 30)});

  final Duration quiet;
  final _last = <String, double>{};
  final _alerted = <String, DateTime>{};

  /// The side crossed (true = above), or null for no alert. [id] names the
  /// node and value.
  bool? judge(String id, double value, TelemetryLimit limit, DateTime now) {
    final before = _last[id];
    _last[id] = value;
    final side = outsideLimit(limit, value);
    if (side == null) return null;
    if (before != null && outsideLimit(limit, before) == side) return null;
    final at = _alerted[id];
    if (at != null && now.difference(at) < quiet) return null;
    _alerted[id] = now;
    return side;
  }
}

/// Checks each newly saved telemetry reply against the limits set for its
/// node and notifies on a crossing.
final telemetryAlertWatcherProvider = Provider<void>((ref) {
  final store = ref.watch(storeProvider);
  final judge = LimitJudge();
  int? lastId;
  final sub = store.watchNewestTelemetry().listen((sample) async {
    if (sample == null) return;
    if (lastId == null) {
      // What was saved before the app started doesn't alert.
      lastId = sample.id;
      return;
    }
    if (sample.id == lastId) return;
    lastId = sample.id;
    final raw = await store
        .watchSettingsWithPrefix(_prefix(sample.radioKey, sample.nodeKey))
        .first;
    if (raw.isEmpty) return;
    final at = DateTime.fromMillisecondsSinceEpoch(sample.at);
    final l10n = alertStrings(ref.read(languageProvider).value);
    String? name;
    for (final r in decodeLpp(sample.data)) {
      final id = limitId(r.channel, r.kind);
      final limit = _decode(raw[id]);
      if (limit == null) continue;
      final side = judge.judge(
        '${sample.radioKey}|${sample.nodeKey}|$id',
        r.value,
        limit,
        at,
      );
      if (side == null) continue;
      name ??=
          (await store.contact(sample.radioKey, sample.nodeKey))?.name ??
          sample.nodeKey.substring(0, 8);
      final what = seriesLabel(
        (channel: r.channel, kind: r.kind, index: 0),
        axis: false,
        l10n: l10n,
      );
      final now = formatValue(r.kind, r.value);
      final edge = formatValue(r.kind, side ? limit.above! : limit.below!);
      unawaited(
        ref
            .read(messageNotifierProvider)
            .show(
              id: '${sample.nodeKey}|$id'.hashCode & 0x7fffffff,
              title: l10n.telemetryAlertTitle,
              body: side
                  ? l10n.telemetryAlertAbove(name, what, now, edge)
                  : l10n.telemetryAlertBelow(name, what, now, edge),
              chat: (
                thread: Threads.direct(sample.nodeKey),
                title: name,
                isChannel: false,
              ),
            ),
      );
    }
  });
  ref.onDispose(sub.cancel);
});
