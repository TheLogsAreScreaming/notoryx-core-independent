/// Sharing what the radio hears with the NOTORYX coverage map: per-hexagon
/// readings in 15-minute buckets, signed with a key of their own, and the
/// rules for what may leave the phone and when.
///
/// Nothing here touches the radio, GPS or network directly, so it can be
/// tested on its own. `coverage_sharing.dart` wires it into the app.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// The coverage map server.
const coverageServer = 'https://coverage.meshmayhem.org';

/// The public map, for people to look at.
const coverageMapUrl = '$coverageServer/';

const coverageUploadFormat = 'notoryx-coverage-hex/1';
const coverageSignedFormat = 'notoryx-coverage-signed/1';
const coverageEraseFormat = 'notoryx-coverage-erase/1';

/// H3 resolution of the hexagons sent: about 0.9 km across.
const coverageResolution = 8;

/// Readings are grouped into buckets this long, aligned to UTC.
const coverageBucket = Duration(minutes: 15);

/// How long readings stay on the phone.
const coverageKeep = Duration(days: 7);

/// The most hexagons sent in one request.
const coverageCellsPerUpload = 50;

/// The most known repeaters listed in one upload.
const coverageDirectoryMax = 500;

/// A fix must be at least this good, in metres, to place a reading.
const coverageMaxAccuracy = 200.0;

/// A fix older than this is not used to place a reading.
const coverageMaxFixAge = Duration(seconds: 30);

/// How many distinct hexagons at each end of a drive stay private.
const coverageHiddenEnds = 2;

/// When readings leave the phone.
enum CoveragePrivacy {
  /// Signed, sent when the 15-minute bucket closes.
  live(Duration.zero),

  /// Signed, sent three hours after the bucket closes.
  delayed(Duration(hours: 3)),

  /// No key, no signature, no name. Times rounded to the day, sent a day
  /// after that day ends.
  anonymous(Duration(hours: 24));

  const CoveragePrivacy(this.delay);

  final Duration delay;
}

// ---------------------------------------------------------------------------
// Canonical JSON and signatures

/// [value] as canonical JSON: object keys sorted, no spaces, and numbers
/// with a whole value written without a decimal point. Everything else is
/// standard JSON.
String canonicalJson(Object? value) {
  final out = StringBuffer();
  _canonical(value, out);
  return out.toString();
}

void _canonical(Object? v, StringBuffer out) {
  switch (v) {
    case null:
      out.write('null');
    case final bool b:
      out.write(b ? 'true' : 'false');
    case final int i:
      out.write(i.toString());
    case final double d:
      if (!d.isFinite) throw ArgumentError.value(d, 'value', 'not finite');
      if (d == d.truncateToDouble()) {
        out.write(d.toInt().toString());
      } else {
        out.write(jsonEncode(d));
      }
    case final String s:
      out.write(jsonEncode(s));
    case final List<Object?> list:
      out.write('[');
      for (var i = 0; i < list.length; i++) {
        if (i > 0) out.write(',');
        _canonical(list[i], out);
      }
      out.write(']');
    case final Map<String, Object?> map:
      final keys = map.keys.toList()..sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(keys[i]))
          ..write(':');
        _canonical(map[keys[i]], out);
      }
      out.write('}');
    default:
      throw ArgumentError.value(v, 'value', 'not JSON');
  }
}

/// The bytes signed for one hexagon reading: a fixed tag, then the cell as
/// canonical JSON without its `sig` and with its repeaters sorted by id.
Uint8List cellSigningBytes(Map<String, Object?> cell) {
  final copy = Map<String, Object?>.of(cell)..remove('sig');
  if (copy['repeaters'] case final List<Object?> reps) {
    final sorted = [...reps]
      ..sort((a, b) => _repeaterId(a).compareTo(_repeaterId(b)));
    copy['repeaters'] = sorted;
  }
  return Uint8List.fromList(
    utf8.encode('$coverageSignedFormat\n${canonicalJson(copy)}'),
  );
}

String _repeaterId(Object? r) => r is Map ? '${r['id']}' : '$r';

/// The coverage key: an Ed25519 key made on this phone only for coverage
/// uploads. It is never the radio's identity.
class CoverageKey {
  CoverageKey.fromSeed(Uint8List seed)
    : assert(seed.length == 32),
      _private = ed.newKeyFromSeed(seed),
      seed = Uint8List.fromList(seed);

  /// A new random key.
  factory CoverageKey.generate([math.Random? random]) {
    final r = random ?? math.Random.secure();
    return CoverageKey.fromSeed(
      Uint8List.fromList(List.generate(32, (_) => r.nextInt(256))),
    );
  }

  final Uint8List seed;
  final ed.PrivateKey _private;

  Uint8List get publicKey => Uint8List.fromList(ed.public(_private).bytes);

  /// The public key in base64, as the server names mappers.
  String get publicBase64 => base64.encode(publicKey);

  /// A base64 Ed25519 signature over [bytes].
  String sign(List<int> bytes) =>
      base64.encode(ed.sign(_private, Uint8List.fromList(bytes)));
}

// ---------------------------------------------------------------------------
// Time

/// The start of the 15-minute UTC bucket holding [at].
DateTime bucketStart(DateTime at) {
  final ms = at.toUtc().millisecondsSinceEpoch;
  final size = coverageBucket.inMilliseconds;
  return DateTime.fromMillisecondsSinceEpoch(ms - ms % size, isUtc: true);
}

/// The start of the UTC day holding [at].
DateTime dayStart(DateTime at) {
  final u = at.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

/// [at] the way the server writes times, e.g. `2026-11-22T09:15:00.000Z`.
String isoUtc(DateTime at) => DateTime.fromMillisecondsSinceEpoch(
  at.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

double _twoPlaces(double v) => (v * 100).roundToDouble() / 100;

// ---------------------------------------------------------------------------
// What's kept on the phone

/// Everything heard in one hexagon in one 15-minute bucket on one drive.
class CoverageBucket {
  CoverageBucket({
    required this.cell,
    required this.start,
    required this.session,
    this.count = 0,
    this.bestSnr,
    this.bestRssi,
    Map<String, double>? repeaters,
    this.hidden = false,
    this.sent = false,
  }) : repeaters = repeaters ?? {};

  factory CoverageBucket.fromJson(Map<String, Object?> j) => CoverageBucket(
    cell: j['cell']! as String,
    start: DateTime.fromMillisecondsSinceEpoch(j['start']! as int, isUtc: true),
    session: j['session']! as int,
    count: j['count']! as int,
    bestSnr: (j['snr'] as num?)?.toDouble(),
    bestRssi: j['rssi'] as int?,
    repeaters: {
      for (final MapEntry(:key, :value)
          in ((j['reps'] as Map?) ?? const {}).entries)
        key as String: (value as num).toDouble(),
    },
    hidden: j['hidden'] == true,
    sent: j['sent'] == true,
  );

  /// H3 index, lowercase hex.
  final String cell;

  /// Bucket start, UTC.
  final DateTime start;

  /// The drive it was heard on.
  final int session;

  int count;
  double? bestSnr;
  int? bestRssi;

  /// Repeaters heard directly, by hop hash in hex, with their best SNR.
  final Map<String, double> repeaters;

  /// Never leaves the phone: the start or end of a drive.
  bool hidden;

  /// Already uploaded.
  bool sent;

  DateTime get end => start.add(coverageBucket);

  Map<String, Object?> toJson() => {
    'cell': cell,
    'start': start.millisecondsSinceEpoch,
    'session': session,
    'count': count,
    'snr': bestSnr,
    'rssi': bestRssi,
    'reps': repeaters,
    if (hidden) 'hidden': true,
    if (sent) 'sent': true,
  };
}

/// One mapping drive, as far as hiding its ends goes.
class CoverageSession {
  CoverageSession({
    required this.id,
    required this.hideEnds,
    this.open = true,
    List<String>? first,
    List<String>? recent,
  }) : first = first ?? [],
       recent = recent ?? [];

  factory CoverageSession.fromJson(Map<String, Object?> j) => CoverageSession(
    id: j['id']! as int,
    hideEnds: j['hide'] == true,
    open: j['open'] == true,
    first: [...?(j['first'] as List?)?.cast<String>()],
    recent: [...?(j['recent'] as List?)?.cast<String>()],
  );

  final int id;

  /// Whether this drive's first and last hexagons stay private. Fixed when
  /// the drive starts, so changing the setting later can't release them.
  final bool hideEnds;
  bool open;

  /// The first distinct hexagons of the drive.
  final List<String> first;

  /// The latest distinct hexagons, held back while the drive goes on.
  final List<String> recent;

  Map<String, Object?> toJson() => {
    'id': id,
    'hide': hideEnds,
    'open': open,
    'first': first,
    'recent': recent,
  };
}

/// The readings kept on the phone, and which of them may be sent.
class CoverageLog {
  CoverageLog({List<CoverageBucket>? buckets, List<CoverageSession>? sessions})
    : buckets = buckets ?? [],
      sessions = {for (final s in sessions ?? const []) s.id: s};

  factory CoverageLog.fromJson(Map<String, Object?> j) => CoverageLog(
    buckets: [
      for (final b in (j['buckets'] as List?) ?? const [])
        CoverageBucket.fromJson((b as Map).cast<String, Object?>()),
    ],
    sessions: [
      for (final s in (j['sessions'] as List?) ?? const [])
        CoverageSession.fromJson((s as Map).cast<String, Object?>()),
    ],
  );

  final List<CoverageBucket> buckets;
  final Map<int, CoverageSession> sessions;

  Map<String, Object?> toJson() => {
    'buckets': [for (final b in buckets) b.toJson()],
    'sessions': [for (final s in sessions.values) s.toJson()],
  };

  /// Records one thing heard in [cell] at [at] on drive [session]. A
  /// [packet] adds to the count; [repeater] is a hop hash heard directly.
  void hear({
    required String cell,
    required DateTime at,
    required int session,
    required bool hideEnds,
    required double snr,
    required int rssi,
    String? repeater,
    bool packet = true,
  }) {
    final s = sessions.putIfAbsent(
      session,
      () => CoverageSession(id: session, hideEnds: hideEnds),
    );
    if (!s.open) return; // a drive already finished
    if (s.first.length < coverageHiddenEnds && !s.first.contains(cell)) {
      s.first.add(cell);
      if (s.hideEnds) {
        for (final b in buckets) {
          if (b.session == session && b.cell == cell) b.hidden = true;
        }
      }
    }
    if (s.recent.isEmpty || s.recent.last != cell) {
      s.recent
        ..remove(cell)
        ..add(cell);
      while (s.recent.length > coverageHiddenEnds) {
        s.recent.removeAt(0);
      }
    }
    final start = bucketStart(at);
    var b = buckets
        .where(
          (b) => b.session == session && b.cell == cell && b.start == start,
        )
        .firstOrNull;
    if (b == null) {
      b = CoverageBucket(
        cell: cell,
        start: start,
        session: session,
        hidden: s.hideEnds && s.first.contains(cell),
      );
      buckets.add(b);
    }
    if (packet || b.count == 0) b.count++;
    if (b.bestSnr == null || snr > b.bestSnr!) b.bestSnr = snr;
    if (b.bestRssi == null || rssi > b.bestRssi!) b.bestRssi = rssi;
    if (repeater != null) {
      final id = repeater.toLowerCase();
      final old = b.repeaters[id];
      if (old == null || snr > old) b.repeaters[id] = snr;
    }
  }

  /// Ends drive [session]: its latest hexagons become private for good.
  void closeSession(int session) {
    final s = sessions[session];
    if (s == null || !s.open) return;
    s.open = false;
    if (!s.hideEnds) return;
    for (final b in buckets) {
      if (b.session == session && s.recent.contains(b.cell)) b.hidden = true;
    }
  }

  /// Ends every drive still open, except [except]: after the app closed
  /// mid-drive, its end is treated as the end.
  void closeOpenSessions({int? except}) {
    for (final s in sessions.values.toList()) {
      if (s.open && s.id != except) closeSession(s.id);
    }
  }

  bool _held(CoverageBucket b) {
    final s = sessions[b.session];
    return s != null && s.open && s.hideEnds && s.recent.contains(b.cell);
  }

  /// When [b] may be sent with [privacy].
  static DateTime releaseAt(CoverageBucket b, CoveragePrivacy privacy) =>
      switch (privacy) {
        CoveragePrivacy.anonymous => dayStart(
          b.start,
        ).add(const Duration(days: 1)).add(privacy.delay),
        _ => b.end.add(privacy.delay),
      };

  /// The readings that may be sent now.
  List<CoverageBucket> due(DateTime now, CoveragePrivacy privacy) => [
    for (final b in buckets)
      if (!b.sent &&
          !b.hidden &&
          b.count > 0 &&
          b.bestSnr != null &&
          b.bestRssi != null &&
          !_held(b) &&
          !now.isBefore(releaseAt(b, privacy)))
        b,
  ];

  /// Readings not yet sent, private ones left out.
  int get waiting => buckets.where((b) => !b.sent && !b.hidden).length;

  /// Drops readings older than [coverageKeep], and finished drives with
  /// nothing left.
  void trim(DateTime now) {
    final cutoff = now.toUtc().subtract(coverageKeep);
    buckets.removeWhere((b) => b.start.isBefore(cutoff));
    final used = {for (final b in buckets) b.session};
    sessions.removeWhere((id, s) => !s.open && !used.contains(id));
  }

  /// Forgets everything kept.
  void clear() {
    buckets.clear();
    sessions.clear();
  }
}

// ---------------------------------------------------------------------------
// Uploads

/// A repeater that advertised where it is, for names and pins on the map.
typedef KnownRepeater = ({
  String publicKey,
  String name,
  double? latitude,
  double? longitude,
  DateTime advert,
});

/// [repeaters] with a real position, newest advert first, at most
/// [coverageDirectoryMax], as the upload lists them.
List<Map<String, Object?>> repeaterDirectory(
  Iterable<KnownRepeater> repeaters,
) {
  final placed = [
    for (final r in repeaters)
      if (r.latitude != null &&
          r.longitude != null &&
          !(r.latitude == 0 && r.longitude == 0) &&
          RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(r.publicKey) &&
          r.name.trim().isNotEmpty)
        r,
  ]..sort((a, b) => b.advert.compareTo(a.advert));
  return [
    for (final r in placed.take(coverageDirectoryMax))
      {
        'key': r.publicKey.toLowerCase(),
        'name': r.name,
        'lat': r.latitude,
        'lon': r.longitude,
        'advert': isoUtc(r.advert),
      },
  ];
}

/// One hexagon as sent, and the readings it stands for.
typedef CoverageCellOut = ({
  Map<String, Object?> json,
  List<CoverageBucket> from,
});

/// [due] as upload cells. Readings of the same hexagon and time are merged
/// (two drives in one bucket); anonymous uploads merge by day. Signed when
/// [key] is given.
List<CoverageCellOut> uploadCells(
  List<CoverageBucket> due,
  CoveragePrivacy privacy, {
  CoverageKey? key,
}) {
  final anonymous = privacy == CoveragePrivacy.anonymous;
  final groups = <String, List<CoverageBucket>>{};
  for (final b in due) {
    final time = anonymous ? dayStart(b.start) : b.start;
    (groups['${b.cell}@${time.millisecondsSinceEpoch}'] ??= []).add(b);
  }
  final out = <CoverageCellOut>[];
  for (final from in groups.values) {
    var count = 0;
    var snr = double.negativeInfinity;
    var rssi = -1 << 31;
    final reps = <String, double>{};
    for (final b in from) {
      count += b.count;
      snr = math.max(snr, b.bestSnr!);
      rssi = math.max(rssi, b.bestRssi!);
      for (final MapEntry(:key, :value) in b.repeaters.entries) {
        reps[key] = math.max(reps[key] ?? double.negativeInfinity, value);
      }
    }
    final first = from.first;
    final ids = reps.keys.toList()..sort();
    final json = <String, Object?>{
      'cell': first.cell,
      'time': isoUtc(anonymous ? dayStart(first.start) : first.start),
      'count': count,
      'best_snr': _twoPlaces(snr),
      'best_rssi': rssi,
      'repeaters': [
        for (final id in ids) {'id': id, 'snr': _twoPlaces(reps[id]!)},
      ],
    };
    if (key != null) json['sig'] = key.sign(cellSigningBytes(json));
    out.add((json: json, from: from));
  }
  return out;
}

/// The body of one upload. [key] is left out for anonymous uploads, and so
/// are [mapper] and [repeaters].
String uploadBody({
  required List<Map<String, Object?>> cells,
  required DateTime created,
  CoverageKey? key,
  String? mapper,
  List<Map<String, Object?>> repeaters = const [],
}) => jsonEncode({
  'format': coverageUploadFormat,
  'resolution': coverageResolution,
  if (key != null) 'key': key.publicBase64,
  'created': isoUtc(created),
  if (key != null && mapper != null && mapper.trim().isNotEmpty)
    'mapper': mapper.trim(),
  if (key != null && repeaters.isNotEmpty) 'repeaters': repeaters,
  'cells': cells,
});

/// Headers for [body]: the key and a signature over the exact bytes.
Map<String, String> signedHeaders(String body, CoverageKey key) => {
  'X-Notoryx-Key': key.publicBase64,
  'X-Notoryx-Signature': key.sign(utf8.encode(body)),
};

/// The body of a request to erase everything [key] uploaded.
String eraseBody(CoverageKey key, DateTime now) => jsonEncode({
  'format': coverageEraseFormat,
  'key': key.publicBase64,
  'time': isoUtc(now),
});

/// An HTTP POST: status and body text.
typedef CoveragePost = Future<({int status, String body})> Function(
  Uri url,
  String body,
  Map<String, String> headers,
);

/// Why an upload or erase did not go through.
class CoverageServerException implements Exception {
  CoverageServerException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => 'coverage server $status: $message';
}

String _serverError(({int status, String body}) r) {
  try {
    final j = jsonDecode(r.body);
    if (j is Map && j['error'] is String) return j['error'] as String;
  } on FormatException {
    // not JSON
  }
  return r.body.length > 200 ? r.body.substring(0, 200) : r.body;
}

/// Sends what's due from [log], [coverageCellsPerUpload] hexagons at a
/// time, and marks what the server took as sent. Returns how many hexagons
/// were sent. Stops at the first failure, which it throws.
Future<int> uploadDue({
  required CoverageLog log,
  required CoveragePrivacy privacy,
  required CoverageKey key,
  required CoveragePost post,
  required DateTime now,
  String? mapper,
  List<Map<String, Object?>> repeaters = const [],
  String server = coverageServer,
}) async {
  final anonymous = privacy == CoveragePrivacy.anonymous;
  final cells = uploadCells(
    log.due(now, privacy),
    privacy,
    key: anonymous ? null : key,
  );
  var sent = 0;
  for (var i = 0; i < cells.length; i += coverageCellsPerUpload) {
    final chunk = cells.sublist(
      i,
      math.min(i + coverageCellsPerUpload, cells.length),
    );
    final body = uploadBody(
      cells: [for (final c in chunk) c.json],
      created: now,
      key: anonymous ? null : key,
      mapper: mapper,
      // The repeater list rides along with the first request only.
      repeaters: i == 0 ? repeaters : const [],
    );
    final res = await post(Uri.parse('$server/v1/reports'), body, {
      'Content-Type': 'application/json',
      if (!anonymous) ...signedHeaders(body, key),
    });
    if (res.status != 200) {
      throw CoverageServerException(res.status, _serverError(res));
    }
    for (final c in chunk) {
      for (final b in c.from) {
        b.sent = true;
      }
    }
    sent += chunk.length;
  }
  return sent;
}

/// Asks the server to delete everything [key] uploaded. Returns how many
/// readings it removed.
Future<int> eraseUploads({
  required CoverageKey key,
  required CoveragePost post,
  required DateTime now,
  String server = coverageServer,
}) async {
  final body = eraseBody(key, now);
  final res = await post(Uri.parse('$server/v1/erase'), body, {
    'Content-Type': 'application/json',
    'X-Notoryx-Signature': key.sign(utf8.encode(body)),
  });
  if (res.status != 200) {
    throw CoverageServerException(res.status, _serverError(res));
  }
  final j = jsonDecode(res.body);
  return j is Map && j['erased'] is num ? (j['erased'] as num).toInt() : 0;
}

/// The hop hash of the repeater a flood packet was last passed on by: the
/// last [hashBytes] bytes of its [path], in hex. Null when it came straight
/// from the sender.
String? lastHopHash(List<int> path, int hashBytes) {
  if (hashBytes < 1 || hashBytes > 3 || path.length < hashBytes) return null;
  final hop = path.sublist(path.length - hashBytes);
  return [for (final b in hop) b.toRadixString(16).padLeft(2, '0')].join();
}
