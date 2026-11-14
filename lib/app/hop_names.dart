/// Naming repeaters from the short IDs in a path: a pick remembered when
/// several known repeaters share an ID, and an optional online lookup for
/// IDs this radio doesn't know.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'connection.dart';

const hopNamesSetting = 'hop_names';
const defaultHopServer = 'https://analyzer.on8ar.eu';
const defaultTieDays = 30;
const maxTieDays = 180;
const defaultTieMargin = 5;
const maxTieMargin = 20;

/// Farther than this, a repeater can't be the one that relayed to you.
const hopRangeMetres = 150000.0;

/// Repeater names settings, remembered picks and names found online.
class HopNames {
  HopNames({
    this.online = false,
    this.server = defaultHopServer,
    this.tieDays = defaultTieDays,
    this.tieMargin = defaultTieMargin,
    Map<String, ({String key, int at})>? ties,
    this.found = const {},
  }) : ties = ties ?? {};

  /// Whether unknown IDs are looked up online.
  final bool online;
  final String server;

  /// How long a remembered pick lasts without being used again.
  final int tieDays;

  /// How close (in %) two repeaters' distances must be for the remembered
  /// pick to decide. 0 means only exact ties.
  final int tieMargin;

  /// Remembered picks: short ID (lower-case hex) → full key, last used
  /// (ms since epoch). Updated in place while naming, without a rebuild.
  final Map<String, ({String key, int at})> ties;

  /// Names found online by short ID (lower-case hex).
  final Map<String, String> found;

  HopNames copyWith({
    bool? online,
    String? server,
    int? tieDays,
    int? tieMargin,
    Map<String, String>? found,
    bool clearTies = false,
  }) => HopNames(
    online: online ?? this.online,
    server: server ?? this.server,
    tieDays: tieDays ?? this.tieDays,
    tieMargin: tieMargin ?? this.tieMargin,
    ties: clearTies ? {} : ties,
    found: found ?? this.found,
  );

  bool isTie(double nearest, double next) =>
      next - nearest <= nearest * tieMargin / 100;

  /// The remembered key for [hash] at [now], or null.
  String? remembered(String hash, DateTime now) {
    final tie = ties[hash.toLowerCase()];
    if (tie == null) return null;
    final age = now.millisecondsSinceEpoch - tie.at;
    if (age > Duration(days: tieDays).inMilliseconds) return null;
    return tie.key;
  }

  /// Unexpired remembered picks at [now].
  int tieCount(DateTime now) => [
    for (final hash in ties.keys)
      if (remembered(hash, now) != null) hash,
  ].length;

  Map<String, Object?> toJson(DateTime now) => {
    'online': online,
    'server': server,
    'tieDays': tieDays,
    'tieMargin': tieMargin,
    'ties': {
      for (final MapEntry(:key, :value) in ties.entries)
        if (remembered(key, now) != null) key: [value.key, value.at],
    },
  };

  static HopNames fromJson(Object? json) {
    if (json is! Map<String, Object?>) return HopNames();
    final ties = <String, ({String key, int at})>{};
    if (json['ties'] case final Map<String, Object?> raw) {
      for (final MapEntry(:key, :value) in raw.entries) {
        if (value case [final String k, final int at]) {
          ties[key] = (key: k, at: at);
        }
      }
    }
    return HopNames(
      online: json['online'] == true,
      server: json['server'] as String? ?? defaultHopServer,
      tieDays: ((json['tieDays'] as int?) ?? defaultTieDays).clamp(
        1,
        maxTieDays,
      ),
      tieMargin: ((json['tieMargin'] as int?) ?? defaultTieMargin).clamp(
        0,
        maxTieMargin,
      ),
      ties: ties,
    );
  }
}

/// What [hopName] can use beyond the repeater list.
class HopHints {
  const HopHints({
    required this.names,
    required this.now,
    this.you,
    this.positions = const {},
    this.onlineLabel,
  });

  final HopNames names;
  final DateTime now;

  /// Where this radio is, if known.
  final LatLng? you;

  /// Known positions by full key (lower-case hex).
  final Map<String, LatLng> positions;

  /// How a name found online is shown, e.g. "Hilltop (online)".
  final String Function(String name)? onlineLabel;
}

/// The name for hop [hash] among [repeaters] (name and full key).
///
/// One match: its name. Several: the nearest to you when positions tell
/// them apart (and that pick is remembered), the remembered pick when they
/// don't, or all of them listed. None: the name found online, if any, else
/// the ID.
String hopName(
  String hash,
  Iterable<({String name, String publicKey})> repeaters, {
  HopHints? hints,
}) {
  final id = hash.toLowerCase();
  final byKey = {
    for (final r in repeaters)
      if (r.publicKey.toLowerCase().startsWith(id))
        r.publicKey.toLowerCase(): r,
  };
  final matches = byKey.values.toList();
  if (matches.length == 1) return matches.single.name;
  if (matches.isEmpty) {
    final online = hints?.names.found[id];
    if (online != null) return hints?.onlineLabel?.call(online) ?? online;
    return hash.toUpperCase();
  }

  if (hints != null) {
    final names = hints.names;
    final remembered = names.remembered(id, hints.now);
    final you = hints.you;
    final measured = <({String key, double metres})>[
      if (you != null)
        for (final key in byKey.keys)
          if (hints.positions[key] case final at?)
            (key: key, metres: const Distance()(you, at)),
    ]..sort((a, b) => a.metres.compareTo(b.metres));
    final inRange = [
      for (final m in measured)
        if (m.metres <= hopRangeMetres) m,
    ];
    String pick(String key) {
      names.ties[id] = (key: key, at: hints.now.millisecondsSinceEpoch);
      return byKey[key]!.name;
    }

    if (inRange.isNotEmpty) {
      final best = inRange.first;
      final close = [
        for (final m in inRange)
          if (names.isTie(best.metres, m.metres)) m.key,
      ];
      if (close.length > 1 && close.contains(remembered)) {
        return pick(remembered!);
      }
      return pick(best.key);
    }
    if (measured.isEmpty && remembered != null && byKey[remembered] != null) {
      return pick(remembered);
    }
  }
  return '${hash.toUpperCase()} (${matches.map((r) => r.name).join(' or ')})';
}

/// The name in a lookup [reply] for [id]: the nearest candidate within
/// range of [you], or, without a position, only an unambiguous answer.
String? onlineHopName(Object? reply, String id, {LatLng? you}) {
  if (reply is! Map<String, Object?>) return null;
  final resolved = reply['resolved'];
  if (resolved is! Map<String, Object?>) return null;
  final entry = resolved[id.toUpperCase()];
  if (entry is! Map<String, Object?>) return null;
  if (you != null) {
    String? best;
    double? bestMetres;
    for (final c in entry['candidates'] as List<Object?>? ?? const []) {
      if (c
          case {
            'name': final String name,
            'lat': final num lat,
            'lon': final num lon,
          }
          when name.trim().isNotEmpty) {
        final metres = const Distance()(
          you,
          LatLng(lat.toDouble(), lon.toDouble()),
        );
        if (metres <= hopRangeMetres &&
            (bestMetres == null || metres < bestMetres)) {
          best = name.trim();
          bestMetres = metres;
        }
      }
    }
    return best;
  }
  if (entry['ambiguous'] == true) return null;
  final name = entry['name'];
  return name is String && name.trim().isNotEmpty ? name.trim() : null;
}

final hopNamesProvider = NotifierProvider<HopNamesNotifier, HopNames>(
  HopNamesNotifier.new,
);

class HopNamesNotifier extends Notifier<HopNames> {
  /// Makes the HTTP request; replaced in tests.
  static Future<Object?> Function(Uri uri) fetch = _get;

  final _asked = <String>{};
  final _pending = <String>{};
  Timer? _batch;
  Timer? _saveSoon;
  LatLng? _near;

  @override
  HopNames build() {
    ref.onDispose(() {
      _batch?.cancel();
      _saveSoon?.cancel();
    });
    unawaited(_load());
    return HopNames();
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(hopNamesSetting);
    if (!ref.mounted || raw == null) return;
    try {
      state = HopNames.fromJson(jsonDecode(raw));
    } on FormatException {
      // Unreadable: keep the defaults.
    }
  }

  Future<void> _save() => ref
      .read(storeProvider)
      .saveSetting(hopNamesSetting, jsonEncode(state.toJson(DateTime.now())));

  /// Saves picks remembered while naming, a little later.
  void picksChanged() {
    _saveSoon?.cancel();
    _saveSoon = Timer(const Duration(seconds: 5), () {
      if (ref.mounted) unawaited(_save());
    });
  }

  Future<void> setOnline(bool on) async {
    state = state.copyWith(online: on);
    await _save();
  }

  Future<void> setServer(String url) async {
    final u = Uri.tryParse(url.trim());
    if (u == null || !u.isScheme('https') || u.host.isEmpty) return;
    _asked.clear();
    state = state.copyWith(server: url.trim(), found: const {});
    await _save();
  }

  Future<void> setTieDays(int days) async {
    state = state.copyWith(tieDays: days.clamp(1, maxTieDays));
    await _save();
  }

  Future<void> setTieMargin(int percent) async {
    state = state.copyWith(tieMargin: percent.clamp(0, maxTieMargin));
    await _save();
  }

  Future<void> forgetPicks() async {
    state = state.copyWith(clearTies: true);
    await _save();
  }

  /// Looks up [ids] online, once each, if that's turned on. Safe to call
  /// while building: the lookup runs afterwards.
  void want(Iterable<String> ids, {LatLng? near}) {
    if (!state.online) return;
    _near = near;
    for (final id in ids) {
      final hex = id.toLowerCase();
      if (_asked.add(hex)) _pending.add(hex);
    }
    if (_pending.isEmpty) return;
    _batch ??= Timer(const Duration(milliseconds: 400), _lookUp);
  }

  Future<void> _lookUp() async {
    _batch = null;
    final ids = _pending.toList();
    _pending.clear();
    if (ids.isEmpty || !ref.mounted) return;
    final uri = Uri.parse(state.server).replace(
      path: '/api/resolve-hops',
      queryParameters: {'hops': ids.map((i) => i.toUpperCase()).join(',')},
    );
    Object? reply;
    try {
      reply = await fetch(uri);
    } on Object {
      reply = null;
    }
    if (!ref.mounted) return;
    if (reply == null) {
      _asked.removeAll(ids); // try again next time
      return;
    }
    final found = {...state.found};
    for (final id in ids) {
      final name = onlineHopName(reply, id, you: _near);
      if (name != null) found[id] = name;
    }
    state = state.copyWith(found: found);
  }

  static Future<Object?> _get(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body);
    } finally {
      client.close();
    }
  }
}

/// Hints for naming hops on a screen showing [radioKey]'s paths.
HopHints hopHints(
  WidgetRef ref,
  String radioKey, {
  String Function(String name)? onlineLabel,
}) {
  final positions = <String, LatLng>{};
  LatLng? at(double? lat, double? lon) =>
      lat == null || lon == null || (lat == 0 && lon == 0)
      ? null
      : LatLng(lat, lon);
  for (final c in ref.watch(contactsProvider(radioKey)).value ?? const []) {
    if (at(c.latitude, c.longitude) case final p?) {
      positions[c.publicKey.toLowerCase()] = p;
    }
  }
  for (final d in ref.watch(discoveredProvider(radioKey)).value ?? const []) {
    if (at(d.latitude, d.longitude) case final p?) {
      positions.putIfAbsent(d.publicKey.toLowerCase(), () => p);
    }
  }
  final state = ref.watch(connectionProvider);
  return HopHints(
    names: ref.watch(hopNamesProvider),
    now: DateTime.now(),
    you: state is Connected
        ? at(state.radio.self.latitude, state.radio.self.longitude)
        : null,
    positions: positions,
    onlineLabel: onlineLabel,
  );
}

/// Call while building a screen that names hops: once the frame is done,
/// saves new picks and looks up the [unknown] IDs it found online (when
/// that's on).
void afterNamingHops(WidgetRef ref, Set<String> unknown, HopHints hints) {
  final notifier = ref.read(hopNamesProvider.notifier);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notifier.picksChanged();
    if (unknown.isNotEmpty) notifier.want(unknown, near: hints.you);
  });
}
