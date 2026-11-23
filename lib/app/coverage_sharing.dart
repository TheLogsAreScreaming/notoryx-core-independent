/// Opt-in sharing with the NOTORYX coverage map: records what the radio
/// hears while a wardrive is running, keeps it on the phone for a week, and
/// sends it when the chosen privacy allows.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:h3_flutter/h3_flutter.dart';

import '../data/data.dart';
import '../radio/protocol/discover.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'coverage_share.dart';
import 'safety.dart';
import 'wardrive.dart';

export 'coverage_share.dart' show CoveragePrivacy, coverageMapUrl;

const _settingsKey = 'coverage_share';
const _seedKey = 'coverage_key_seed';
const _logKey = 'coverage_share_log';

/// How often waiting readings are checked and sent.
const coverageUploadEvery = Duration(minutes: 5);

/// The user's choices.
@immutable
class CoverageShareSettings {
  const CoverageShareSettings({
    this.enabled = false,
    this.privacy = CoveragePrivacy.delayed,
    this.wifiOnly = true,
    this.hideEnds = true,
    this.mapper = '',
  });

  factory CoverageShareSettings.fromJson(Map<String, Object?> j) =>
      CoverageShareSettings(
        enabled: j['enabled'] == true,
        privacy:
            CoveragePrivacy.values.asNameMap()[j['privacy']] ??
            CoveragePrivacy.delayed,
        wifiOnly: j['wifiOnly'] != false,
        hideEnds: j['hideEnds'] != false,
        mapper: j['mapper'] as String? ?? '',
      );

  /// The user agreed and sharing is on.
  final bool enabled;
  final CoveragePrivacy privacy;
  final bool wifiOnly;

  /// Keep the first and last hexagons of every drive private.
  final bool hideEnds;

  /// Name shown to coverage map members. Never sent anonymously.
  final String mapper;

  CoverageShareSettings copyWith({
    bool? enabled,
    CoveragePrivacy? privacy,
    bool? wifiOnly,
    bool? hideEnds,
    String? mapper,
  }) => CoverageShareSettings(
    enabled: enabled ?? this.enabled,
    privacy: privacy ?? this.privacy,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    hideEnds: hideEnds ?? this.hideEnds,
    mapper: mapper ?? this.mapper,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'privacy': privacy.name,
    'wifiOnly': wifiOnly,
    'hideEnds': hideEnds,
    'mapper': mapper,
  };
}

/// What the sharing screen shows.
@immutable
class CoverageShareState {
  const CoverageShareState({
    this.settings = const CoverageShareSettings(),
    this.loaded = false,
    this.waiting = 0,
    this.sentTotal = 0,
    this.lastSent,
    this.lastError,
  });

  final CoverageShareSettings settings;
  final bool loaded;

  /// Hexagon readings kept and not yet sent (private ones left out).
  final int waiting;

  /// Hexagon readings sent since the app started.
  final int sentTotal;
  final DateTime? lastSent;
  final String? lastError;

  CoverageShareState copyWith({
    CoverageShareSettings? settings,
    bool? loaded,
    int? waiting,
    int? sentTotal,
    DateTime? lastSent,
    String? lastError,
    bool clearError = false,
  }) => CoverageShareState(
    settings: settings ?? this.settings,
    loaded: loaded ?? this.loaded,
    waiting: waiting ?? this.waiting,
    sentTotal: sentTotal ?? this.sentTotal,
    lastSent: lastSent ?? this.lastSent,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

/// A phone position with how good and how old it is.
typedef CoverageFix = ({
  double latitude,
  double longitude,
  double accuracy,
  DateTime time,
});

/// The phone's positions while mapping. Tests replace this.
final coverageFixesProvider = Provider<Stream<CoverageFix> Function()>(
  (ref) =>
      () =>
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          ).map(
            (p) => (
              latitude: p.latitude,
              longitude: p.longitude,
              accuracy: p.accuracy,
              time: p.timestamp,
            ),
          ),
);

H3? _h3;

/// The H3 resolution-8 hexagon holding a point, or null if H3 isn't
/// available. Tests replace this.
final coverageCellOfProvider = Provider<String? Function(double, double)>(
  (ref) => (lat, lon) {
    try {
      final h3 = _h3 ??= const H3Factory().load();
      return h3
          .geoToCell(GeoCoord(lat: lat, lon: lon), coverageResolution)
          .toRadixString(16);
    } on Object {
      return null;
    }
  },
);

/// Whether the phone is on Wi-Fi (or a cable). Tests replace this.
final coverageOnWifiProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final kinds = await Connectivity().checkConnectivity();
    return kinds.contains(ConnectivityResult.wifi) ||
        kinds.contains(ConnectivityResult.ethernet);
  },
);

/// Sends to the coverage server. Tests replace this.
final coveragePostProvider = Provider<CoveragePost>((ref) => _ioPost);

Future<({int status, String body})> _ioPost(
  Uri url,
  String body,
  Map<String, String> headers,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.postUrl(url);
    headers.forEach(req.headers.set);
    req.add(utf8.encode(body));
    final res = await req.close().timeout(const Duration(seconds: 30));
    return (
      status: res.statusCode,
      body: await res.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

final coverageSharingProvider =
    NotifierProvider<CoverageSharing, CoverageShareState>(CoverageSharing.new);

class CoverageSharing extends Notifier<CoverageShareState> {
  CoverageLog _log = CoverageLog();
  CoverageKey? _key;
  CoverageFix? _fix;
  StreamSubscription<RxLog>? _heard;
  StreamSubscription<PushFrame>? _pushes;
  StreamSubscription<CoverageFix>? _fixes;
  DateTime? _fixTried;
  Timer? _timer;
  Timer? _saveSoon;
  bool _uploading = false;
  late final Future<void> _ready;

  @override
  CoverageShareState build() {
    // Ref can't be used while disposing, so the store is kept from here.
    final store = ref.read(storeProvider);
    ref.onDispose(() {
      unawaited(_heard?.cancel());
      unawaited(_pushes?.cancel());
      unawaited(_fixes?.cancel());
      _timer?.cancel();
      if (_saveSoon?.isActive ?? false) {
        _saveSoon!.cancel();
        unawaited(
          store
              .saveSetting(_logKey, jsonEncode(_log.toJson()))
              .then<void>((_) {}, onError: (Object _) {}),
        );
      }
    });
    _ready = _load();
    ref.listen(connectionProvider, (_, next) => _follow(next));
    ref.listen(wardriveProvider, (before, now) => _driveChanged(before, now));
    return const CoverageShareState();
  }

  DateTime _now() => ref.read(safetyClockProvider)().toUtc();
  MeshStore get _store => ref.read(storeProvider);

  Future<void> _load() async {
    try {
      final raw = await _store.setting(_settingsKey);
      final logRaw = await _store.setting(_logKey);
      if (!ref.mounted) return;
      final settings = raw == null
          ? const CoverageShareSettings()
          : CoverageShareSettings.fromJson(
              (jsonDecode(raw) as Map).cast<String, Object?>(),
            );
      if (logRaw != null) {
        _log = CoverageLog.fromJson(
          (jsonDecode(logRaw) as Map).cast<String, Object?>(),
        );
      }
      // A drive left open by the app closing ends here, so its last
      // hexagons stay private.
      _log.closeOpenSessions(except: ref.read(wardriveProvider));
      _log.trim(_now());
      state = state.copyWith(
        settings: settings,
        loaded: true,
        waiting: _log.waiting,
      );
      _restart();
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('coverage sharing load: $e');
      state = state.copyWith(loaded: true);
    }
  }

  /// Starts or stops listening and the upload timer to match the settings.
  void _restart() {
    _timer?.cancel();
    _timer = null;
    _follow(ref.read(connectionProvider));
    _followFixes();
    if (state.settings.enabled) {
      _timer = Timer.periodic(coverageUploadEvery, (_) => unawaited(upload()));
      unawaited(upload());
    }
  }

  bool get _recording =>
      state.settings.enabled && ref.read(wardriveProvider) != null;

  void _follow(RadioConnectionState connection) {
    unawaited(_heard?.cancel());
    unawaited(_pushes?.cancel());
    _heard = null;
    _pushes = null;
    if (!state.settings.enabled || connection is! Connected) return;
    _heard = connection.sync.heard.listen(_onHeard);
    _pushes = connection.sync.session.pushes.listen(_onPush);
  }

  void _followFixes() {
    final want = _recording;
    if (!want) {
      unawaited(_fixes?.cancel());
      _fixes = null;
      _fix = null;
      return;
    }
    if (_fixes != null) return;
    _fixTried = _now();
    // A stream that fails (say location wasn't allowed yet) is dropped, and
    // opened again the next time the radio hears something.
    void drop() {
      unawaited(_fixes?.cancel());
      _fixes = null;
    }

    try {
      _fixes = ref
          .read(coverageFixesProvider)()
          .listen(
            (f) => _fix = f,
            onError: (Object e) {
              ref.read(connectionLogProvider).add('coverage GPS: $e');
              drop();
            },
            onDone: drop,
            cancelOnError: true,
          );
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('coverage GPS: $e');
      _fixes = null;
    }
  }

  void _driveChanged(int? before, int? now) {
    if (before != null && before != now) {
      _log.closeSession(before);
      _changed(saveNow: true);
      unawaited(upload());
    }
    _followFixes();
  }

  /// Where the phone is, if the fix is good and fresh enough.
  String? _cellNow() {
    if (_fixes == null &&
        (_fixTried == null ||
            _now().difference(_fixTried!) > coverageMaxFixAge)) {
      _followFixes();
    }
    final f = _fix;
    if (f == null || f.accuracy > coverageMaxAccuracy) return null;
    if (_now().difference(f.time.toUtc()) > coverageMaxFixAge) return null;
    return ref.read(coverageCellOfProvider)(f.latitude, f.longitude);
  }

  void _onHeard(RxLog log) {
    final drive = ref.read(wardriveProvider);
    if (!state.settings.enabled || drive == null) return;
    final cell = _cellNow();
    if (cell == null) return;
    final header = PacketHeader.parse(log.packet);
    // On a flood the path's last hop is the repeater we heard directly.
    final isFlood =
        header != null &&
        (header.route == RouteKind.flood ||
            header.route == RouteKind.transportFlood);
    final hop = isFlood ? lastHopHash(header.path, header.hashBytes) : null;
    _log.hear(
      cell: cell,
      at: _now(),
      session: drive,
      hideEnds: state.settings.hideEnds,
      snr: log.snr,
      rssi: log.rssi,
      repeater: hop,
    );
    _changed();
  }

  /// A repeater answering a wardrive ping was heard directly.
  void _onPush(PushFrame p) {
    if (p is! ControlData) return;
    final drive = ref.read(wardriveProvider);
    if (!state.settings.enabled || drive == null) return;
    final answer = parseDiscoverAnswer(p.payload);
    if (answer == null || answer.publicKey.length < 2) return;
    final cell = _cellNow();
    if (cell == null) return;
    _log.hear(
      cell: cell,
      at: _now(),
      session: drive,
      hideEnds: state.settings.hideEnds,
      snr: p.snr,
      rssi: p.rssi,
      repeater: answer.publicKey.substring(0, 2),
      packet: false,
    );
    _changed();
  }

  void _changed({bool saveNow = false}) {
    state = state.copyWith(waiting: _log.waiting);
    if (saveNow) {
      _saveSoon?.cancel();
      unawaited(_saveLog());
      return;
    }
    if (_saveSoon?.isActive ?? false) return;
    _saveSoon = Timer(const Duration(seconds: 10), () => unawaited(_saveLog()));
  }

  Future<void> _saveLog() async {
    try {
      await _store.saveSetting(_logKey, jsonEncode(_log.toJson()));
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('coverage sharing save: $e');
    }
  }

  Future<void> _saveSettings(CoverageShareSettings s) async {
    state = state.copyWith(settings: s);
    await _store.saveSetting(_settingsKey, jsonEncode(s.toJson()));
    _restart();
  }

  /// The coverage key, made the first time it's needed.
  Future<CoverageKey> _coverageKey() async {
    if (_key case final k?) return k;
    final saved = await _store.setting(_seedKey);
    if (saved != null) {
      try {
        final seed = base64.decode(saved);
        if (seed.length == 32) return _key = CoverageKey.fromSeed(seed);
      } on FormatException {
        // remade below
      }
    }
    final key = CoverageKey.generate();
    await _store.saveSetting(_seedKey, base64.encode(key.seed));
    return _key = key;
  }

  /// The coverage key's public half, to show the user. Null before the
  /// first upload or erase.
  Future<String?> publicKey() async {
    final saved = await _store.setting(_seedKey);
    if (saved == null) return null;
    try {
      return CoverageKey.fromSeed(Uint8List.fromList(base64.decode(saved)))
          .publicBase64;
    } on Object {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // What the screen calls

  /// Turns sharing on, after the user agreed to what's sent.
  Future<void> agreeAndStart() async {
    await _ready;
    await _coverageKey();
    // A drive already running counts from now, as a new drive.
    await _saveSettings(state.settings.copyWith(enabled: true));
  }

  /// Turns sharing off. Readings not sent yet are deleted from the phone.
  Future<void> stop() async {
    await _ready;
    _log.clear();
    await _saveLog();
    state = state.copyWith(waiting: 0, clearError: true);
    await _saveSettings(state.settings.copyWith(enabled: false));
  }

  Future<void> setPrivacy(CoveragePrivacy p) async {
    await _ready;
    await _saveSettings(state.settings.copyWith(privacy: p));
  }

  Future<void> setWifiOnly(bool on) async {
    await _ready;
    await _saveSettings(state.settings.copyWith(wifiOnly: on));
  }

  Future<void> setHideEnds(bool on) async {
    await _ready;
    await _saveSettings(state.settings.copyWith(hideEnds: on));
  }

  Future<void> setMapper(String name) async {
    await _ready;
    final clean = name.replaceAll(RegExp(r'[\x00-\x1f\x7f<>]'), '').trim();
    await _saveSettings(
      state.settings.copyWith(
        mapper: clean.length > 32 ? clean.substring(0, 32) : clean,
      ),
    );
  }

  /// Deletes everything this phone's coverage key uploaded. Returns how many
  /// readings the server removed.
  Future<int> eraseMyUploads() async {
    await _ready;
    final saved = await _store.setting(_seedKey);
    if (saved == null) return 0; // nothing was ever signed
    final key = await _coverageKey();
    return eraseUploads(
      key: key,
      post: ref.read(coveragePostProvider),
      now: _now(),
    );
  }

  /// Sends whatever is due. Quietly does nothing when sharing is off, off
  /// Wi-Fi with Wi-Fi only on, or already sending.
  Future<void> upload() async {
    await _ready;
    if (!state.settings.enabled || _uploading) return;
    final now = _now();
    _log.trim(now);
    if (_log.due(now, state.settings.privacy).isEmpty) {
      _changed();
      return;
    }
    _uploading = true;
    try {
      if (state.settings.wifiOnly &&
          !await ref.read(coverageOnWifiProvider)()) {
        return;
      }
      final key = await _coverageKey();
      final anonymous = state.settings.privacy == CoveragePrivacy.anonymous;
      final sent = await uploadDue(
        log: _log,
        privacy: state.settings.privacy,
        key: key,
        post: ref.read(coveragePostProvider),
        now: now,
        mapper: anonymous ? null : state.settings.mapper,
        repeaters: anonymous ? const [] : await _directory(now),
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        sentTotal: state.sentTotal + sent,
        lastSent: now,
        clearError: true,
      );
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('coverage upload: $e');
      if (ref.mounted) state = state.copyWith(lastError: '$e');
    } finally {
      _uploading = false;
      if (ref.mounted) _changed(saveNow: true);
    }
  }

  /// Repeaters this phone knows with an advertised position.
  Future<List<Map<String, Object?>>> _directory(DateTime now) async {
    final db = ref.read(databaseProvider);
    final repeater = NodeType.repeater.value;
    final contacts = await (db.select(
      db.contacts,
    )..where((c) => c.type.equals(repeater))).get();
    final heard = await (db.select(
      db.discovered,
    )..where((c) => c.type.equals(repeater))).get();
    DateTime when(int seconds) {
      final t = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );
      return t.isAfter(now) ? now : t; // a node's clock can run ahead
    }

    final byKey = <String, KnownRepeater>{};
    void add(KnownRepeater r) {
      final old = byKey[r.publicKey];
      if (old == null || r.advert.isAfter(old.advert)) byKey[r.publicKey] = r;
    }

    for (final c in contacts) {
      add((
        publicKey: c.publicKey,
        name: c.name,
        latitude: c.latitude,
        longitude: c.longitude,
        advert: when(c.lastAdvert),
      ));
    }
    for (final c in heard) {
      add((
        publicKey: c.publicKey,
        name: c.name,
        latitude: c.latitude,
        longitude: c.longitude,
        advert: when(c.lastAdvert),
      ));
    }
    return repeaterDirectory(byKey.values);
  }
}
