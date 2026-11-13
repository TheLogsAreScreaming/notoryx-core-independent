/// Zone and off-trail alerts from the positions your radio hears.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../l10n/generated/app_localizations.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'contact_room.dart' show isFavourite;
import 'language.dart';
import 'notifications.dart';

/// When a zone alerts.
enum ZoneAlertOn {
  enter,
  leave,
  both;

  bool get onEnter => this != leave;
  bool get onLeave => this != enter;
}

/// A circle that alerts when someone crosses its edge.
typedef Zone = ({
  String id,
  String name,
  double lat,
  double lon,
  double radius,
  ZoneAlertOn on,
});

/// Someone whose position is watched.
typedef Watched = ({String key, String name, double lat, double lon});

enum ZoneAlertKind { entered, left, offTrail }

typedef ZoneAlert = ({
  ZoneAlertKind kind,
  String key,
  String name,
  Zone? zone,
  double? metres,
});

const _earth = 6371008.8;
double _rad(double d) => d * math.pi / 180;

/// Great-circle distance in metres.
double metresBetween(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1), dLon = _rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earth * math.asin(math.min(1, math.sqrt(a)));
}

/// Shortest distance from a point to the line through [trail], in metres;
/// each segment is flattened around the point. Null for an empty trail.
double? metresFromTrail(
  double lat,
  double lon,
  List<({double lat, double lon})> trail,
) {
  if (trail.isEmpty) return null;
  final k = math.cos(_rad(lat));
  ({double x, double y}) local(({double lat, double lon}) p) =>
      (x: _rad(p.lon - lon) * k * _earth, y: _rad(p.lat - lat) * _earth);
  var a = local(trail.first);
  var best = math.sqrt(a.x * a.x + a.y * a.y);
  for (var i = 1; i < trail.length; i++) {
    final b = local(trail[i]);
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : (-(a.x * dx + a.y * dy) / len2).clamp(0.0, 1.0);
    final px = a.x + t * dx, py = a.y + t * dy;
    best = math.min(best, math.sqrt(px * px + py * py));
    a = b;
  }
  return best;
}

/// "120 m" or "1.5 km".
String shortDistance(double metres) => metres < 1000
    ? '${metres.round()} m'
    : '${(metres / 1000).toStringAsFixed(metres < 10000 ? 1 : 0)} km';

/// Turns positions into alerts. The first position seen for someone only
/// records; zone edges have 10% slack (at least 15 m) and the trail needs
/// someone back within 70% of the limit before it alerts again, so a
/// position wobbling on an edge alerts once.
class ZoneWatcher {
  final Map<String, Set<String>> _inside = {};
  final Map<String, bool> _offTrail = {};

  void reset() {
    _inside.clear();
    _offTrail.clear();
  }

  void forgetTrail() => _offTrail.clear();

  void forgetZone(String id) {
    for (final s in _inside.values) {
      s.remove(id);
    }
  }

  List<ZoneAlert> observe(
    Iterable<Watched> people, {
    required List<Zone> zones,
    List<({double lat, double lon})> trail = const [],
    double offTrailMetres = 100,
  }) {
    final out = <ZoneAlert>[];
    for (final p in people) {
      final known = _inside[p.key];
      final inside = <String>{};
      for (final z in zones) {
        final d = metresBetween(p.lat, p.lon, z.lat, z.lon);
        final was = known?.contains(z.id) ?? false;
        final slack = math.max(15.0, z.radius * .1);
        final now = was ? d <= z.radius + slack : d <= z.radius;
        if (now) inside.add(z.id);
        if (known == null || now == was) continue;
        if (now && z.on.onEnter) {
          out.add((
            kind: ZoneAlertKind.entered,
            key: p.key,
            name: p.name,
            zone: z,
            metres: null,
          ));
        } else if (!now && z.on.onLeave) {
          out.add((
            kind: ZoneAlertKind.left,
            key: p.key,
            name: p.name,
            zone: z,
            metres: null,
          ));
        }
      }
      _inside[p.key] = inside;

      final d = metresFromTrail(p.lat, p.lon, trail);
      if (d == null) {
        _offTrail.remove(p.key);
        continue;
      }
      final was = _offTrail[p.key];
      final off = (was ?? false) ? d > offTrailMetres * .7 : d > offTrailMetres;
      _offTrail[p.key] = off;
      if (was == false && off) {
        out.add((
          kind: ZoneAlertKind.offTrail,
          key: p.key,
          name: p.name,
          zone: null,
          metres: d,
        ));
      }
    }
    return out;
  }
}

/// What's watched, kept as one setting.
class ZoneSettings {
  const ZoneSettings({
    this.enabled = false,
    this.favouritesOnly = true,
    this.includeRadio = true,
    this.zones = const [],
    this.trackId,
    this.trail = const [],
    this.offTrailMetres = 100,
  });

  final bool enabled;
  final bool favouritesOnly;
  final bool includeRadio;
  final List<Zone> zones;

  /// The recorded track watched as the trail, or null.
  final int? trackId;

  /// Its points, loaded when chosen.
  final List<({double lat, double lon})> trail;
  final double offTrailMetres;

  static const key = 'zones.v1';
  static const maxZones = 50;

  ZoneSettings copyWith({
    bool? enabled,
    bool? favouritesOnly,
    bool? includeRadio,
    List<Zone>? zones,
    int? Function()? trackId,
    List<({double lat, double lon})>? trail,
    double? offTrailMetres,
  }) => ZoneSettings(
    enabled: enabled ?? this.enabled,
    favouritesOnly: favouritesOnly ?? this.favouritesOnly,
    includeRadio: includeRadio ?? this.includeRadio,
    zones: zones ?? this.zones,
    trackId: trackId == null ? this.trackId : trackId(),
    trail: trail ?? this.trail,
    offTrailMetres: offTrailMetres ?? this.offTrailMetres,
  );

  String encode() => jsonEncode({
    'on': enabled,
    'fav': favouritesOnly,
    'radio': includeRadio,
    'track': trackId,
    'off': offTrailMetres,
    'zones': [
      for (final z in zones)
        {
          'id': z.id,
          'name': z.name,
          'lat': z.lat,
          'lon': z.lon,
          'r': z.radius,
          'on': z.on.name,
        },
    ],
  });

  static ZoneSettings decode(String? raw) {
    if (raw == null) return const ZoneSettings();
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const ZoneSettings();
      final off = j['off'];
      final track = j['track'];
      return ZoneSettings(
        enabled: j['on'] == true,
        favouritesOnly: j['fav'] != false,
        includeRadio: j['radio'] != false,
        trackId: track is int ? track : null,
        offTrailMetres: off is num && off > 0 ? off.toDouble() : 100,
        zones: [
          for (final z in j['zones'] as List? ?? const [])
            if (z is Map &&
                z['id'] is String &&
                z['name'] is String &&
                z['lat'] is num &&
                z['lon'] is num &&
                z['r'] is num)
              (
                id: z['id'] as String,
                name: z['name'] as String,
                lat: (z['lat'] as num).toDouble(),
                lon: (z['lon'] as num).toDouble(),
                radius: (z['r'] as num).toDouble().clamp(50.0, 10000.0),
                on: ZoneAlertOn.values.firstWhere(
                  (e) => e.name == z['on'],
                  orElse: () => ZoneAlertOn.both,
                ),
              ),
        ],
      );
    } on FormatException {
      return const ZoneSettings();
    }
  }
}

final zoneSettingsProvider =
    AsyncNotifierProvider<ZoneSettingsNotifier, ZoneSettings>(
      ZoneSettingsNotifier.new,
    );

class ZoneSettingsNotifier extends AsyncNotifier<ZoneSettings> {
  MeshStore get _store => ref.read(storeProvider);

  @override
  Future<ZoneSettings> build() async {
    final s = ZoneSettings.decode(await _store.setting(ZoneSettings.key));
    final id = s.trackId;
    return id == null ? s : s.copyWith(trail: await _points(id));
  }

  Future<List<({double lat, double lon})>> _points(int id) async => [
    for (final p in await _store.watchTrackPoints(id).first)
      (lat: p.latitude, lon: p.longitude),
  ];

  Future<void> _set(ZoneSettings s) async {
    state = AsyncData(s);
    await _store.saveSetting(ZoneSettings.key, s.encode());
  }

  ZoneSettings get _now => state.value ?? const ZoneSettings();

  Future<void> setEnabled(bool on) => _set(_now.copyWith(enabled: on));
  Future<void> setFavouritesOnly(bool on) =>
      _set(_now.copyWith(favouritesOnly: on));
  Future<void> setIncludeRadio(bool on) =>
      _set(_now.copyWith(includeRadio: on));
  Future<void> setOffTrailMetres(double m) =>
      _set(_now.copyWith(offTrailMetres: m));

  Future<void> setTrack(int? id) async => _set(
    _now.copyWith(
      trackId: () => id,
      trail: id == null ? const [] : await _points(id),
    ),
  );

  /// Adds or replaces [zone]; false when there are already [maxZones].
  Future<bool> saveZone(Zone zone) async {
    final zones = [..._now.zones];
    final i = zones.indexWhere((z) => z.id == zone.id);
    if (i >= 0) {
      zones[i] = zone;
    } else if (zones.length >= ZoneSettings.maxZones) {
      return false;
    } else {
      zones.add(zone);
    }
    await _set(_now.copyWith(zones: zones));
    return true;
  }

  Future<void> deleteZone(String id) =>
      _set(_now.copyWith(zones: [..._now.zones.where((z) => z.id != id)]));
}

/// Everyone watched who has a position now.
List<Watched> watchedPeople(
  ZoneSettings s,
  List<Contact> contacts, {
  ({String name, double lat, double lon})? radio,
}) => [
  if (s.includeRadio && radio != null)
    (key: 'self', name: radio.name, lat: radio.lat, lon: radio.lon),
  for (final c in contacts)
    if (NodeType.fromByte(c.type) == NodeType.chat &&
        c.latitude != null &&
        c.longitude != null &&
        !(c.latitude == 0 && c.longitude == 0) &&
        (!s.favouritesOnly || isFavourite(c)))
      (key: c.publicKey, name: c.name, lat: c.latitude!, lon: c.longitude!),
];

/// The language alerts are written in: the one chosen in the app, else
/// the phone's, else English.
AppLocalizations alertStrings(Locale? chosen) {
  final l = chosen ?? PlatformDispatcher.instance.locale;
  return lookupAppLocalizations(
    AppLocalizations.supportedLocales.any(
          (s) => s.languageCode == l.languageCode,
        )
        ? Locale(l.languageCode)
        : const Locale('en'),
  );
}

({String title, String body}) zoneAlertText(AppLocalizations l, ZoneAlert a) =>
    switch (a.kind) {
      ZoneAlertKind.entered => (
        title: l.zoneEnteredTitle(a.zone!.name),
        body: l.zoneEnteredBody(a.name, a.zone!.name),
      ),
      ZoneAlertKind.left => (
        title: l.zoneLeftTitle(a.zone!.name),
        body: l.zoneLeftBody(a.name, a.zone!.name),
      ),
      ZoneAlertKind.offTrail => (
        title: l.offTrailTitle,
        body: l.offTrailBody(a.name, shortDistance(a.metres ?? 0)),
      ),
    };

/// Watches positions while a radio is connected and notifies.
final zoneWatcherProvider = Provider<void>((ref) {
  final watcher = ZoneWatcher();
  String? radioKey;
  var lastTrack = ref.read(zoneSettingsProvider).value?.trackId;

  void check() {
    final s = ref.read(zoneSettingsProvider).value;
    final state = ref.read(connectionProvider);
    if (s == null || !s.enabled || state is! Connected) return;
    if (s.zones.isEmpty && s.trail.isEmpty) return;
    if (state.radio.key != radioKey) {
      radioKey = state.radio.key;
      watcher.reset();
    }
    if (s.trackId != lastTrack) {
      lastTrack = s.trackId;
      watcher.forgetTrail();
    }
    final self = state.radio.self;
    final contacts =
        ref.read(contactsProvider(state.radio.key)).value ?? const [];
    final people = watchedPeople(
      s,
      contacts,
      radio: self.latitude == null || self.longitude == null
          ? null
          : (name: self.name, lat: self.latitude!, lon: self.longitude!),
    );
    final alerts = watcher.observe(
      people,
      zones: s.zones,
      trail: s.trail,
      offTrailMetres: s.offTrailMetres,
    );
    if (alerts.isEmpty) return;
    final l = alertStrings(ref.read(languageProvider).value);
    final notifier = ref.read(messageNotifierProvider);
    for (final a in alerts) {
      final text = zoneAlertText(l, a);
      unawaited(
        notifier.show(
          id: '${a.kind.name}|${a.key}|${a.zone?.id}'.hashCode & 0x7fffffff,
          title: text.title,
          body: text.body,
          chat: (
            thread: a.key == 'self' ? '' : Threads.direct(a.key),
            title: a.name,
            isChannel: false,
          ),
        ),
      );
    }
  }

  ref.listen(connectionProvider, (prev, next) {
    if (next is! Connected) watcher.reset();
    check();
  });
  ref.listen(zoneSettingsProvider, (prev, next) {
    final before = prev?.value, now = next.value;
    if (before != null && now != null && before.enabled != now.enabled) {
      watcher.reset();
    }
    check();
  });
  ref.listen(radioKeyProvider, (_, key) {
    if (key == null) return;
    ref.listen(contactsProvider(key), (_, _) => check());
  }, fireImmediately: true);
});
