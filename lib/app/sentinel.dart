import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'connection.dart';

/// The NOTORYX Sentinel relay. It holds the moderation service's keys, so
/// this app never does. Source: TheLogsAreScreaming/notoryx-sentinel-relay.
const sentinelRelayUrl = 'https://sentinel-relay.meshmayhem.org';

/// The node ID Sentinel uses for a MeshCore channel sender known only by
/// name (MeshCore channel messages carry no key).
String sentinelNameId(String name) {
  final id = 'name:${name.trim()}';
  return id.length <= 64 ? id : id.substring(0, 64);
}

/// This app's network on the relay.
const sentinelNetwork = 'meshcore';

/// One HTTP exchange with the relay. Swapped out in tests.
typedef SentinelResponse = ({int status, String body});
typedef SentinelTransport = Future<SentinelResponse> Function(
  String method,
  Uri url,
  String? body,
);

Future<SentinelResponse> _ioTransport(
  String method,
  Uri url,
  String? body,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.openUrl(method, url);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(body));
    }
    final res = await req.close();
    return (
      status: res.statusCode,
      body: await res.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

/// Why a node is being reported. The wire text stays English because
/// moderators read it.
enum SentinelReason {
  spam('Spam or advertising'),
  flooding('Flooding the mesh'),
  abuse('Harassment or abuse'),
  impersonation('Impersonation'),
  other('Other');

  const SentinelReason(this.wire);
  final String wire;
}

/// A node with a moderator-approved ban. Advisory only: nothing on the mesh
/// is blocked, and the user can ignore it.
@immutable
class SentinelBan {
  const SentinelBan({
    required this.nodeId,
    required this.caseRef,
    this.appealPending = false,
  });

  final String nodeId;
  final String caseRef;
  final bool appealPending;

  static SentinelBan? fromJson(Object? json) {
    if (json is! Map) return null;
    final nodeId = json['nodeId'];
    final caseRef = json['caseRef'];
    if (nodeId is! String || caseRef is! String) return null;
    if (nodeId.isEmpty || caseRef.isEmpty) return null;
    return SentinelBan(
      nodeId: nodeId.toLowerCase().startsWith('name:')
          ? nodeId
          : nodeId.toLowerCase(),
      caseRef: caseRef,
      appealPending: json['appealPending'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'nodeId': nodeId,
    'caseRef': caseRef,
    'appealPending': appealPending,
  };
}

/// A report waiting to be sent. [externalRef] makes resending safe.
@immutable
class SentinelReport {
  const SentinelReport({
    required this.nodeId,
    required this.reason,
    required this.externalRef,
    this.nodeName,
    this.messageExcerpt,
  });

  final String nodeId;
  final String? nodeName;
  final String reason;
  final String? messageExcerpt;
  final String externalRef;

  Map<String, Object?> toWire() => {
    'nodeId': nodeId,
    'nodeName': ?nodeName,
    'reason': reason,
    'messageExcerpt': ?messageExcerpt,
    'externalRef': externalRef,
  };

  Map<String, Object?> toJson() => toWire();

  static SentinelReport? fromJson(Object? json) {
    if (json is! Map) return null;
    final nodeId = json['nodeId'];
    final reason = json['reason'];
    final ref = json['externalRef'];
    if (nodeId is! String || reason is! String || ref is! String) {
      return null;
    }
    final name = json['nodeName'];
    final excerpt = json['messageExcerpt'];
    return SentinelReport(
      nodeId: nodeId,
      nodeName: name is String ? name : null,
      reason: reason,
      messageExcerpt: excerpt is String ? excerpt : null,
      externalRef: ref,
    );
  }
}

/// What happened to a report.
sealed class SentinelReportOutcome {
  const SentinelReportOutcome();
}

/// The relay accepted it; moderators will see case [caseRef].
class SentinelReportSent extends SentinelReportOutcome {
  const SentinelReportSent(this.caseRef);
  final String caseRef;
}

/// No connection (or the service is busy); kept and sent later.
class SentinelReportQueued extends SentinelReportOutcome {
  const SentinelReportQueued();
}

/// The relay refused it and resending won't help.
class SentinelReportRejected extends SentinelReportOutcome {
  const SentinelReportRejected(this.message);
  final String message;
}

/// What happened to an appeal.
enum SentinelAppealOutcome {
  received,
  unknownCase,
  notAppealable,
  tooMany,
  failed,
}

/// Reads and writes one saved setting.
typedef SentinelRead = Future<String?> Function(String name);
typedef SentinelWrite = Future<void> Function(String name, String value);

String _randomRef() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Opt-in link to NOTORYX Sentinel, the human-reviewed moderation service,
/// for MeshCore: files spam reports (queued while offline), keeps the
/// advisory lists of banned nodes, and relays appeals.
///
/// Off by default. While off it makes no network requests at all.
class SentinelService extends ChangeNotifier {
  SentinelService({
    required this._read,
    required this._write,
    SentinelTransport? transport,
    String baseUrl = sentinelRelayUrl,
    DateTime Function()? now,
    String Function()? newRef,
  }) : _transport = transport ?? _ioTransport,
       _base = baseUrl,
       _now = now ?? DateTime.now,
       _newRef = newRef ?? _randomRef;

  final SentinelRead _read;
  final SentinelWrite _write;
  final SentinelTransport _transport;
  final String _base;
  final DateTime Function() _now;
  final String Function() _newRef;

  static const prefEnabled = 'sentinel.enabled';
  static const prefHide = 'sentinel.hide_flagged';
  static const prefBans = 'sentinel.bans';
  static const prefSynced = 'sentinel.synced_at';
  static const prefQueue = 'sentinel.queue';
  static const prefSent = 'sentinel.sent';

  static const _timeout = Duration(seconds: 15);
  static const syncEvery = Duration(hours: 6);
  static const _minSyncGap = Duration(minutes: 5);
  static const maxQueue = 50;
  static const maxSentHistory = 20;
  static const maxExcerpt = 280;
  static const maxNote = 200;

  bool _enabled = false;
  bool _hideFlagged = false;
  Map<String, SentinelBan> _bans = const {};
  DateTime? _syncedAt;
  List<SentinelReport> _queue = const [];
  List<({String caseRef, String? nodeName, DateTime at})> _sent = const [];
  Timer? _timer;
  bool _syncing = false;
  Future<bool>? _inflight;
  bool _flushing = false;
  bool _disposed = false;

  bool get enabled => _enabled;

  /// Whether messages from flagged senders are hidden.
  bool get hideFlagged => _hideFlagged;
  DateTime? get syncedAt => _syncedAt;
  bool get syncing => _syncing;
  int get queuedCount => _queue.length;
  int get flaggedCount => _bans.length;
  List<({String caseRef, String? nodeName, DateTime at})> get sentReports =>
      List.unmodifiable(_sent);

  /// The ban on the contact with this public key (hex), if any.
  SentinelBan? banForKey(String publicKeyHex) =>
      _enabled ? _bans[publicKeyHex.toLowerCase()] : null;

  /// The ban on a channel sender known only by [name], if any.
  SentinelBan? banForName(String name) =>
      _enabled && name.trim().isNotEmpty ? _bans[sentinelNameId(name)] : null;

  /// The ban that applies to [m]'s sender, if any.
  SentinelBan? banForMessage(Message m) {
    if (m.outgoing) return null;
    return switch (m.kind) {
      MessageKind.direct => banForKey(m.thread.substring(2)),
      MessageKind.channel => banForName(m.senderName ?? ''),
    };
  }

  /// Whether [m] is hidden because the user chose to hide flagged senders.
  bool hides(Message m) => _hideFlagged && banForMessage(m) != null;

  Future<void> _set(String name, String value) async {
    try {
      await _write(name, value);
    } on Object {
      // Storage unavailable; kept for this session only.
    }
  }

  Future<String?> _get(String name) async {
    try {
      return await _read(name);
    } on Object {
      return null;
    }
  }

  /// Loads saved state; if the user has opted in, syncs now and every six
  /// hours and sends any queued reports.
  Future<void> start() async {
    _enabled = await _get(prefEnabled) == 'true';
    _hideFlagged = await _get(prefHide) == 'true';
    _syncedAt = DateTime.tryParse(await _get(prefSynced) ?? '');
    _bans = _decodeBans(await _get(prefBans));
    _queue = _decodeQueue(await _get(prefQueue));
    _sent = _decodeSent(await _get(prefSent));
    _notify();
    if (_enabled) _schedule();
  }

  static Map<String, SentinelBan> _decodeBans(String? raw) {
    if (raw == null) return const {};
    try {
      final j = jsonDecode(raw);
      return j is List ? _index(j) : const {};
    } on FormatException {
      return const {};
    }
  }

  static Map<String, SentinelBan> _index(List<Object?> list) {
    final out = <String, SentinelBan>{};
    for (final j in list) {
      final b = SentinelBan.fromJson(j);
      if (b != null) out[b.nodeId] = b;
    }
    return out;
  }

  static List<SentinelReport> _decodeQueue(String? raw) {
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final j in list) ?SentinelReport.fromJson(j)];
    } on FormatException {
      return const [];
    }
  }

  static List<({String caseRef, String? nodeName, DateTime at})> _decodeSent(
    String? raw,
  ) {
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final j in list)
          if (j is Map &&
              j['caseRef'] is String &&
              DateTime.tryParse('${j['at']}') != null)
            (
              caseRef: j['caseRef'] as String,
              nodeName: j['nodeName'] is String
                  ? j['nodeName'] as String
                  : null,
              at: DateTime.parse('${j['at']}'),
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(syncEvery, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  /// Turns the feature on or off. Turning it off forgets the ban lists and
  /// any unsent reports.
  Future<void> setEnabled(bool on) async {
    if (on == _enabled) return;
    _enabled = on;
    await _set(prefEnabled, '$on');
    if (on) {
      _schedule();
    } else {
      _timer?.cancel();
      _timer = null;
      _bans = const {};
      _queue = const [];
      _syncedAt = null;
      await _set(prefBans, '[]');
      await _set(prefQueue, '[]');
      await _set(prefSynced, '');
    }
    _notify();
  }

  Future<void> setHideFlagged(bool on) async {
    _hideFlagged = on;
    await _set(prefHide, '$on');
    _notify();
  }

  /// Syncs the ban list and sends queued reports.
  Future<void> refresh({bool force = false}) async {
    if (!_enabled) return;
    await syncDecisions(force: force);
    await flushQueue();
  }

  Uri _uri(String route) => Uri.parse('$_base/v1/$sentinelNetwork/$route');

  /// Fetches both advisory ban lists (at most once every five minutes
  /// unless [force]d). Keeps the last good lists when offline.
  Future<bool> syncDecisions({bool force = false}) {
    if (!_enabled) return Future.value(false);
    final running = _inflight;
    if (running != null) return running;
    final last = _syncedAt;
    if (!force && last != null && _now().difference(last) < _minSyncGap) {
      return Future.value(true);
    }
    final f = _download().whenComplete(() => _inflight = null);
    _inflight = f;
    return f;
  }

  Future<bool> _download() async {
    _syncing = true;
    _notify();
    try {
      final res = await _transport(
        'GET',
        _uri('decisions'),
        null,
      ).timeout(_timeout);
      if (res.status != 200) return false;
      final body = jsonDecode(res.body);
      if (body is! Map || body['bans'] is! List) return false;
      _bans = _index(body['bans'] as List);
      _syncedAt = _now();
      await _set(
        prefBans,
        jsonEncode([for (final b in _bans.values) b.toJson()]),
      );
      await _set(prefSynced, _syncedAt!.toUtc().toIso8601String());
      return true;
    } on Object {
      return false;
    } finally {
      _syncing = false;
      _notify();
    }
  }

  /// Builds the reason moderators read: the category, then the user's note.
  static String reasonText(SentinelReason reason, String? note) {
    final n = note?.trim() ?? '';
    if (n.isEmpty) return reason.wire;
    return '${reason.wire}: ${n.length > maxNote ? n.substring(0, maxNote) : n}';
  }

  /// Reports a node. Sends now if possible; otherwise queues it for later.
  Future<SentinelReportOutcome> report({
    required String nodeId,
    required SentinelReason reason,
    String? nodeName,
    String? note,
    String? messageExcerpt,
  }) async {
    if (!_enabled) {
      return const SentinelReportRejected('Community moderation is off');
    }
    final excerpt = messageExcerpt?.trim();
    final name = nodeName?.trim();
    final r = SentinelReport(
      nodeId: nodeId.trim(),
      nodeName: name == null || name.isEmpty
          ? null
          : (name.length > 64 ? name.substring(0, 64) : name),
      reason: reasonText(reason, note),
      messageExcerpt: excerpt == null || excerpt.isEmpty
          ? null
          : (excerpt.length > maxExcerpt
                ? excerpt.substring(0, maxExcerpt)
                : excerpt),
      externalRef: _newRef(),
    );
    final outcome = await _send(r);
    if (outcome is SentinelReportQueued) await _enqueue(r);
    return outcome;
  }

  Future<SentinelReportOutcome> _send(SentinelReport r) async {
    try {
      final res = await _transport(
        'POST',
        _uri('reports'),
        jsonEncode(r.toWire()),
      ).timeout(_timeout);
      if (res.status == 200 || res.status == 201) {
        final body = jsonDecode(res.body);
        final ref = body is Map ? body['caseRef'] : null;
        if (ref is String) {
          await _remember(ref, r.nodeName);
          return SentinelReportSent(ref);
        }
        return const SentinelReportQueued();
      }
      if (const {400, 404, 413, 415}.contains(res.status)) {
        var message = 'Rejected (HTTP ${res.status})';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['error'] is String) {
            message = body['error'] as String;
          }
        } on FormatException {
          // keep the generic message
        }
        return SentinelReportRejected(message);
      }
      return const SentinelReportQueued();
    } on Object {
      return const SentinelReportQueued();
    }
  }

  Future<void> _remember(String caseRef, String? nodeName) async {
    if (_sent.any((s) => s.caseRef == caseRef)) return;
    _sent = [
      (caseRef: caseRef, nodeName: nodeName, at: _now()),
      ..._sent,
    ].take(maxSentHistory).toList();
    await _set(
      prefSent,
      jsonEncode([
        for (final s in _sent)
          {
            'caseRef': s.caseRef,
            'nodeName': s.nodeName,
            'at': s.at.toUtc().toIso8601String(),
          },
      ]),
    );
    _notify();
  }

  Future<void> _enqueue(SentinelReport r) async {
    final next = [..._queue, r];
    _queue = next.length > maxQueue
        ? next.sublist(next.length - maxQueue)
        : next;
    await _saveQueue();
    _notify();
  }

  Future<void> _saveQueue() =>
      _set(prefQueue, jsonEncode([for (final r in _queue) r.toJson()]));

  /// Sends queued reports, oldest first; stops at the first that still
  /// can't go, and drops ones the relay rejects outright.
  Future<int> flushQueue() async {
    if (!_enabled || _flushing || _queue.isEmpty) return 0;
    _flushing = true;
    var sent = 0;
    try {
      while (_queue.isNotEmpty && _enabled) {
        final outcome = await _send(_queue.first);
        if (outcome is SentinelReportQueued) break;
        _queue = _queue.sublist(1);
        await _saveQueue();
        if (outcome is SentinelReportSent) sent++;
      }
    } finally {
      _flushing = false;
      _notify();
    }
    return sent;
  }

  /// Appeals a ban on one of the user's own nodes.
  Future<SentinelAppealOutcome> appeal({
    required String caseRef,
    required String statement,
    String? contact,
  }) async {
    if (!_enabled) return SentinelAppealOutcome.failed;
    final c = contact?.trim();
    try {
      final res = await _transport(
        'POST',
        _uri('appeals'),
        jsonEncode({
          'caseRef': caseRef.trim().toUpperCase(),
          'statement': statement.trim(),
          if (c != null && c.isNotEmpty) 'contact': c,
        }),
      ).timeout(_timeout);
      switch (res.status) {
        case 200 || 201:
          unawaited(syncDecisions(force: true));
          return SentinelAppealOutcome.received;
        case 404:
          return SentinelAppealOutcome.unknownCase;
        case 409:
          return SentinelAppealOutcome.notAppealable;
        case 429:
          return SentinelAppealOutcome.tooMany;
        default:
          return SentinelAppealOutcome.failed;
      }
    } on Object {
      return SentinelAppealOutcome.failed;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// The app's moderation service, started on first use.
final sentinelProvider = Provider<SentinelService>((ref) {
  final store = ref.watch(storeProvider);
  final s = SentinelService(read: store.setting, write: store.saveSetting);
  ref.onDispose(s.dispose);
  unawaited(s.start());
  return s;
});
