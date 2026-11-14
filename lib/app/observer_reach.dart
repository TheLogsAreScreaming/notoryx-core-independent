/// Observer reach: asking a packet-analyzer server which of its observers
/// (listening stations) heard this radio directly, and which repeaters it
/// links with. Off by default; nothing is sent until it's turned on.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';
import 'hop_names.dart' show defaultHopServer;

const observerReachSetting = 'observer_reach';

/// The default analyzer server, the same public one repeater names use.
const defaultReachServer = defaultHopServer;

/// Whether observer reach is on and which server it asks.
class ReachSettings {
  const ReachSettings({this.on = false, this.server = defaultReachServer});

  /// Whether the radio's public key may be sent to [server].
  final bool on;
  final String server;

  ReachSettings copyWith({bool? on, String? server}) =>
      ReachSettings(on: on ?? this.on, server: server ?? this.server);

  Map<String, Object?> toJson() => {'on': on, 'server': server};

  static ReachSettings fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const ReachSettings();
    final server = json['server'];
    return ReachSettings(
      on: json['on'] == true,
      server: server is String && validServer(server) != null
          ? server
          : defaultReachServer,
    );
  }

  /// The host shown to people, e.g. "analyzer.example.org".
  String get host => Uri.tryParse(server)?.host ?? server;
}

/// [url] trimmed if it's an https address with a host, else null.
String? validServer(String url) {
  final trimmed = url.trim();
  final u = Uri.tryParse(trimmed);
  if (u == null || !u.isScheme('https') || u.host.isEmpty) return null;
  return trimmed;
}

/// One observer that heard the radio directly.
class ReachObserver {
  const ReachObserver({
    required this.key,
    required this.name,
    required this.count,
    this.snr,
    this.km,
  });

  final String key;
  final String name;

  /// How many of the radio's packets it heard in the window.
  final int count;

  /// Average signal-to-noise ratio in dB, if given.
  final double? snr;

  /// Distance from the radio in km, if both positions are known.
  final double? km;
}

/// A repeater the radio and it hear each other (or one way).
class ReachLink {
  const ReachLink({
    required this.key,
    required this.name,
    required this.weHear,
    required this.theyHear,
    required this.both,
    this.km,
  });

  final String key;
  final String name;

  /// Packets from that repeater relayed by the radio, and the other way.
  final int weHear;
  final int theyHear;

  /// Whether both directions were seen.
  final bool both;
  final double? km;
}

/// What the server knows about who heard the radio.
class ObserverReach {
  const ObserverReach({
    required this.days,
    required this.observers,
    required this.links,
  });

  /// How many days the figures cover.
  final int days;

  /// Observers that heard it directly, most packets first.
  final List<ReachObserver> observers;

  /// Linked repeaters, strongest link first.
  final List<ReachLink> links;

  /// Reads a reply; null if it isn't one.
  static ObserverReach? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    if (json['node'] is! Map<String, Object?>) return null;
    final window = json['window'];
    final days = window is Map<String, Object?> && window['days'] is int
        ? window['days']! as int
        : 7;
    double? number(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    String label(Object? name, String key) =>
        name is String && name.trim().isNotEmpty
        ? name.trim()
        : key.substring(0, key.length < 8 ? key.length : 8).toUpperCase();

    List<Map<String, Object?>> rows(Object? v) => [
      for (final row in v is List<Object?> ? v : const <Object?>[])
        if (row is Map<String, Object?> &&
            row['pubkey'] is String &&
            (row['pubkey']! as String).isNotEmpty)
          row,
    ];

    final observers = <ReachObserver>[
      for (final o in rows(json['direct_observers']))
        if (o['count'] case final int count when count > 0)
          ReachObserver(
            key: o['pubkey']! as String,
            name: label(o['name'], o['pubkey']! as String),
            count: count,
            snr: number(o['avg_snr']),
            km: number(o['distance_km']),
          ),
    ]..sort((a, b) => b.count.compareTo(a.count));

    int count(Object? v) => v is int && v > 0 ? v : 0;
    final links = <ReachLink>[
      for (final l in rows(json['links']))
        ReachLink(
          key: l['pubkey']! as String,
          name: label(l['name'], l['pubkey']! as String),
          weHear: count(l['we_hear']),
          theyHear: count(l['they_hear']),
          both: l['bidir'] == true,
          km: number(l['distance_km']),
        ),
    ]..sort((a, b) => _strength(b).compareTo(_strength(a)));

    return ObserverReach(
      days: days.clamp(1, 365),
      observers: observers,
      links: links,
    );
  }

  static int _strength(ReachLink l) =>
      l.weHear < l.theyHear ? l.weHear : l.theyHear;
}

/// The answer to one reach check.
sealed class ReachResult {
  const ReachResult();
}

/// Observer reach is off: nothing was sent.
final class ReachOff extends ReachResult {
  const ReachOff();
}

final class ReachFound extends ReachResult {
  const ReachFound(this.reach);
  final ObserverReach reach;
}

/// The server has no record of the radio (no observer has heard it).
final class ReachUnknown extends ReachResult {
  const ReachUnknown();
}

/// The server couldn't be reached or sent something unreadable.
final class ReachFailed extends ReachResult {
  const ReachFailed();
}

/// The address asked for [nodeKey]'s reach on [server].
Uri reachUri(String server, String nodeKey) => Uri.parse(server)
    .replace(path: '/api/nodes/${nodeKey.toLowerCase()}/reach', query: null);

/// An HTTP GET: the status code and decoded JSON body (null if not JSON).
typedef ReachFetch = Future<({int status, Object? body})> Function(Uri uri);

final observerReachProvider = NotifierProvider<ReachNotifier, ReachSettings>(
  ReachNotifier.new,
);

class ReachNotifier extends Notifier<ReachSettings> {
  /// Makes the HTTP request; replaced in tests.
  static ReachFetch fetch = _get;

  @override
  ReachSettings build() {
    unawaited(_load());
    return const ReachSettings();
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(observerReachSetting);
    if (!ref.mounted || raw == null) return;
    try {
      state = ReachSettings.fromJson(jsonDecode(raw));
    } on FormatException {
      // Unreadable: keep it off.
    }
  }

  Future<void> _save() => ref
      .read(storeProvider)
      .saveSetting(observerReachSetting, jsonEncode(state.toJson()));

  Future<void> setOn(bool on) async {
    state = state.copyWith(on: on);
    await _save();
  }

  /// Changes the server; returns false (and keeps the old one) if [url]
  /// isn't an https address.
  Future<bool> setServer(String url) async {
    final server = validServer(url);
    if (server == null) return false;
    state = state.copyWith(server: server);
    await _save();
    return true;
  }

  /// Asks the server about [nodeKey]. Sends nothing while it's off.
  Future<ReachResult> check(String nodeKey) async {
    final settings = state;
    if (!settings.on) return const ReachOff();
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(nodeKey)) {
      return const ReachFailed();
    }
    try {
      final reply = await fetch(reachUri(settings.server, nodeKey));
      if (reply.status == 404) return const ReachUnknown();
      if (reply.status != 200) return const ReachFailed();
      final reach = ObserverReach.fromJson(reply.body);
      return reach == null ? const ReachFailed() : ReachFound(reach);
    } on Object {
      return const ReachFailed();
    }
  }

  static Future<({int status, Object? body})> _get(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await response.transform(utf8.decoder).join();
      Object? body;
      try {
        body = jsonDecode(text);
      } on FormatException {
        body = null;
      }
      return (status: response.statusCode, body: body);
    } finally {
      client.close();
    }
  }
}
