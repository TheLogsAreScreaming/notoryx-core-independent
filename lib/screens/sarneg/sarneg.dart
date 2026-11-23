// SARNEG: Search And Rescue Numerical Encryption Grid.
//
// A team agrees on a 10-letter code word with no repeated letter. Letter 1
// stands for 0, letter 2 for 1, and so on, so with BLACKHORSE the number 17
// is sent as LR. It hides numbers from a casual listener. It is NOT
// encryption: anyone who hears a few messages can work the word out.
//
// Wire format shared by every NOTORYX app, so they can read
// each other's messages:
//
//   [SARNEG] LRs KSAC
//
// After the marker, each digit becomes its code letter in UPPER case and
// every other letter is sent in lower case, so decoding never mistakes a
// plain letter for a digit. Everything else (spaces, '.', '-', ',', ':')
// goes as is.
//
// The code word moves between phones as text or a QR code:
//
//   SARNEG1:BLACKHORSE;2026-11-21=CUMBERLAND;2026-11-22=DUMBWAITER
//
// The first word is the default. Each dated entry replaces it on that
// local calendar day, so a team can load a week of words at once.
//
// Options that stay on this phone (never in the shared text):
// - Keep the grid zone in clear: in `17S 4823` the zone `17` is sent as
//   digits (`17s KSAC`). Digits always pass through decoding, so every
//   decoder reads it.
// - Send without the marker, and read unmarked messages: an unmarked
//   message is offered for decoding only when its upper-case letters all
//   belong to the day's word.
// - SARDOT: `sardot 045 2.3km` is a bearing and distance from a secret
//   reference point; with SARNEG on, its digits are coded like any others.

import 'dart:math';

/// Put at the start of a message whose body is SARNEG-encoded.
const String kSarnegMarker = '[SARNEG]';

/// Start of a shared code word (text or QR code).
const String kSarnegSharePrefix = 'SARNEG1:';

/// Most dated words one code set holds.
const int kSarnegMaxDailyWords = 62;

/// How long a decoded result or a shown code word stays on screen.
const Duration kSarnegShowFor = Duration(seconds: 60);

/// How long a copied SARNEG text stays on the clipboard.
const Duration kSarnegClipboardFor = Duration(seconds: 60);

/// Code words printed as examples in public guides. Anyone can try them, so
/// the setup screen warns about them.
const Set<String> kSarnegWellKnownWords = {
  'BLACKHORSE',
  'AFTERSHOCK',
  'CORNFLAKES',
  'COMBATHELP',
  'BACKGROUND',
  'CUMBERLAND',
  'DUMBWAITER',
  'PATHFINDER',
};

/// Whether [word] is one of [kSarnegWellKnownWords].
bool isWellKnownSarnegWord(String word) =>
    kSarnegWellKnownWords.contains(normalizeSarnegWord(word));

/// A new code word of 10 different letters, picked at random.
///
/// Uses [random] when given (for tests), otherwise [Random.secure].
String randomSarnegWord([Random? random]) {
  final letters = [for (var i = 0; i < 26; i++) String.fromCharCode(65 + i)]
    ..shuffle(random ?? Random.secure());
  return letters.take(10).join();
}

/// Why a code word cannot be used.
enum SarnegWordProblem {
  /// Not exactly 10 letters.
  length,

  /// Something other than the letters A to Z.
  letters,

  /// A letter appears twice.
  repeats,
}

/// [word] trimmed, without spaces, in upper case.
String normalizeSarnegWord(String word) =>
    word.replaceAll(RegExp(r'\s'), '').toUpperCase();

/// What is wrong with [word] (already normalized), or null when it can be used.
SarnegWordProblem? checkSarnegWord(String word) {
  if (!RegExp(r'^[A-Z]*$').hasMatch(word)) {
    return SarnegWordProblem.letters;
  }
  if (word.length != 10) {
    return SarnegWordProblem.length;
  }
  if (word.split('').toSet().length != 10) {
    return SarnegWordProblem.repeats;
  }
  return null;
}

/// Turns digits into letters and back with one code word.
class SarnegCodec {
  /// Uses [word], which must pass [checkSarnegWord].
  SarnegCodec(this.word) {
    if (checkSarnegWord(word) != null) {
      throw ArgumentError.value(word, 'word', 'not a SARNEG code word');
    }
  }

  /// The 10-letter code word.
  final String word;

  static final RegExp _digit = RegExp(r'[0-9]');

  /// [plain] with every digit replaced by its code letter (upper case) and
  /// every other letter in lower case.
  ///
  /// With [keepZone], the digits of an MGRS grid zone (`17S`, `4Q`) stay as
  /// digits.
  String encode(String plain, {bool keepZone = false}) {
    final clear = keepZone ? sarnegZoneDigits(plain) : const <int>{};
    final out = StringBuffer();
    for (var i = 0; i < plain.length; i++) {
      final ch = plain[i];
      if (_digit.hasMatch(ch) && !clear.contains(i)) {
        out.write(word[int.parse(ch)]);
      } else {
        out.write(ch.toLowerCase());
      }
    }
    return out.toString();
  }

  /// [coded] with every upper-case code letter turned back into its digit.
  /// Lower-case letters and everything else stay as they are.
  String decode(String coded) {
    final out = StringBuffer();
    for (final ch in coded.split('')) {
      final i = word.indexOf(ch);
      out.write(i >= 0 ? '$i' : ch);
    }
    return out.toString();
  }

  /// A whole message ready to send: the marker, a space and [plain] encoded.
  /// Without [marker] only the coded text is sent.
  String encodeMessage(
    String plain, {
    bool keepZone = false,
    bool marker = true,
  }) {
    final coded = encode(plain.trim(), keepZone: keepZone);
    return marker ? '$kSarnegMarker $coded' : coded;
  }

  /// Whether [text], which has no marker, may be SARNEG with this word: it
  /// has two upper-case letters in a row, and every upper-case letter in it
  /// belongs to the word.
  bool mayBeUnmarked(String text) {
    if (isSarnegMessage(text)) return false;
    final upper = RegExp('[A-Z]').allMatches(text).map((m) => m[0]!);
    if (upper.isEmpty || upper.any((c) => !word.contains(c))) return false;
    return RegExp('[A-Z]{2}').hasMatch(text);
  }

  /// [message] decoded: the body after the marker, or the whole text when
  /// it has none.
  String decodeAny(String message) => decode(sarnegBody(message) ?? message);

  /// The plain text of [message], or null when it has no SARNEG marker.
  String? decodeMessage(String message) {
    final body = sarnegBody(message);
    return body == null ? null : decode(body);
  }
}

/// Whether [message] starts with the SARNEG marker.
bool isSarnegMessage(String message) =>
    message.trimLeft().startsWith(kSarnegMarker);

/// What follows the marker in [message], or null when there is no marker.
String? sarnegBody(String message) {
  final t = message.trimLeft();
  if (!t.startsWith(kSarnegMarker)) {
    return null;
  }
  return t.substring(kSarnegMarker.length).trim();
}

/// `yyyy-mm-dd` for the local calendar day of [t].
String sarnegDay(DateTime t) {
  final l = t.isUtc ? t.toLocal() : t;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}';
}

/// A team's code words: a default plus optional words for given days.
class SarnegKeySet {
  /// Creates a set. Every word must pass [checkSarnegWord].
  SarnegKeySet({required this.word, Map<String, String> daily = const {}})
    : daily = Map.unmodifiable(
        Map.fromEntries(
          daily.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        ),
      ) {
    if (checkSarnegWord(word) != null) {
      throw ArgumentError.value(word, 'word', 'not a SARNEG code word');
    }
    if (this.daily.length > kSarnegMaxDailyWords) {
      throw ArgumentError('more than $kSarnegMaxDailyWords dated words');
    }
    for (final e in this.daily.entries) {
      if (!_dayPattern.hasMatch(e.key)) {
        throw ArgumentError.value(e.key, 'daily', 'not a yyyy-mm-dd day');
      }
      if (checkSarnegWord(e.value) != null) {
        throw ArgumentError.value(e.value, 'daily', 'not a SARNEG code word');
      }
    }
  }

  static final RegExp _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Used on any day without its own word.
  final String word;

  /// Words for given local days, keyed `yyyy-mm-dd`, in date order.
  final Map<String, String> daily;

  /// The word for the local day of [at].
  String wordFor(DateTime at) => daily[sarnegDay(at)] ?? word;

  /// A codec for the local day of [at].
  SarnegCodec codecFor(DateTime at) => SarnegCodec(wordFor(at));

  /// This set with [day]'s word set to [dayWord], or removed when null.
  SarnegKeySet withDay(String day, String? dayWord) {
    final next = Map<String, String>.of(daily);
    if (dayWord == null) {
      next.remove(day);
    } else {
      next[day] = dayWord;
    }
    return SarnegKeySet(word: word, daily: next);
  }

  /// This set without dated words for days before [today] (`yyyy-mm-dd`).
  SarnegKeySet withoutDaysBefore(String today) => SarnegKeySet(
    word: word,
    daily: {
      for (final e in daily.entries)
        if (e.key.compareTo(today) >= 0) e.key: e.value,
    },
  );

  /// The text to share or show as a QR code.
  String toShareText() => [
    '$kSarnegSharePrefix$word',
    for (final e in daily.entries) '${e.key}=${e.value}',
  ].join(';');

  /// Reads [text] made by [toShareText]. Throws [FormatException] when it is
  /// not a code set.
  static SarnegKeySet parseShareText(String text) {
    final t = text.trim();
    if (!t.toUpperCase().startsWith(kSarnegSharePrefix)) {
      throw const FormatException('Not a SARNEG code word');
    }
    final parts = t.substring(kSarnegSharePrefix.length).split(';');
    final word = normalizeSarnegWord(parts.first);
    if (checkSarnegWord(word) != null) {
      throw const FormatException('The code word is not 10 different letters');
    }
    final daily = <String, String>{};
    for (final p in parts.skip(1)) {
      if (p.trim().isEmpty) {
        continue;
      }
      final eq = p.indexOf('=');
      if (eq < 0) {
        throw const FormatException('A dated word is missing its date');
      }
      final day = p.substring(0, eq).trim();
      final w = normalizeSarnegWord(p.substring(eq + 1));
      if (!_dayPattern.hasMatch(day) || !_validDay(day)) {
        throw FormatException('Not a date: $day');
      }
      if (checkSarnegWord(w) != null) {
        throw FormatException('The word for $day is not 10 different letters');
      }
      daily[day] = w;
    }
    if (daily.length > kSarnegMaxDailyWords) {
      throw const FormatException('Too many dated words');
    }
    return SarnegKeySet(word: word, daily: daily);
  }

  static bool _validDay(String day) {
    final d = DateTime.tryParse(day);
    return d != null && sarnegDay(d) == day;
  }

  /// For saving.
  Map<String, Object> toJson() => {'word': word, 'daily': daily};

  /// Reads [toJson] output; null when it is damaged.
  static SarnegKeySet? fromJson(Object? json) {
    try {
      if (json is! Map) {
        return null;
      }
      final word = json['word'];
      final daily = json['daily'];
      if (word is! String) {
        return null;
      }
      return SarnegKeySet(
        word: word,
        daily: daily is Map
            ? {for (final e in daily.entries) '${e.key}': '${e.value}'}
            : const {},
      );
    } on ArgumentError {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SarnegKeySet &&
      other.word == word &&
      other.daily.length == daily.length &&
      daily.entries.every((e) => other.daily[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    word,
    Object.hashAllUnordered(daily.entries.map((e) => '${e.key}=${e.value}')),
  );
}

/// Positions in [text] of the digits of MGRS grid zones (1 to 60 followed by
/// a latitude band letter, then two square letters or the end of the word).
Set<int> sarnegZoneDigits(String text) {
  final out = <int>{};
  final zone = RegExp(
    r'(?<![0-9A-Za-z])(\d{1,2})(?=[C-HJ-NP-Xc-hj-np-x](?:[A-HJ-NP-Za-hj-np-z]{2})?(?![A-Za-z]))',
  );
  for (final m in zone.allMatches(text)) {
    final n = int.parse(m[1]!);
    if (n < 1 || n > 60) continue;
    for (var i = m.start; i < m.end; i++) {
      out.add(i);
    }
  }
  return out;
}

/// Settings that stay on this phone. None of them are in the shared text.
class SarnegOptions {
  /// Creates options; every field is optional.
  const SarnegOptions({
    this.keepZone = false,
    this.noMarker = false,
    this.readUnmarked = false,
    this.wipeAfter,
    this.sardotLat,
    this.sardotLon,
    this.numberOfDay,
    this.letterOfDay,
  });

  /// Send MGRS grid zones as digits.
  final bool keepZone;

  /// Send coded text without the `[SARNEG]` marker.
  final bool noMarker;

  /// Offer to decode messages without the marker.
  final bool readUnmarked;

  /// Every word is deleted after this local day (`yyyy-mm-dd`).
  final String? wipeAfter;

  /// SARDOT reference point (secret; never sent).
  final double? sardotLat;

  /// SARDOT reference point longitude.
  final double? sardotLon;

  /// Number of the day (0 to 99), for challenge and reply.
  final int? numberOfDay;

  /// Letter of the day (A to Z).
  final String? letterOfDay;

  /// Whether a SARDOT reference point is set.
  bool get hasSardot => sardotLat != null && sardotLon != null;

  /// A copy with the given changes. Pass [clearWipe], [clearSardot] or
  /// [clearAuth] to remove those values.
  SarnegOptions copyWith({
    bool? keepZone,
    bool? noMarker,
    bool? readUnmarked,
    String? wipeAfter,
    bool clearWipe = false,
    double? sardotLat,
    double? sardotLon,
    bool clearSardot = false,
    int? numberOfDay,
    String? letterOfDay,
    bool clearAuth = false,
  }) => SarnegOptions(
    keepZone: keepZone ?? this.keepZone,
    noMarker: noMarker ?? this.noMarker,
    readUnmarked: readUnmarked ?? this.readUnmarked,
    wipeAfter: clearWipe ? null : wipeAfter ?? this.wipeAfter,
    sardotLat: clearSardot ? null : sardotLat ?? this.sardotLat,
    sardotLon: clearSardot ? null : sardotLon ?? this.sardotLon,
    numberOfDay: clearAuth ? null : numberOfDay ?? this.numberOfDay,
    letterOfDay: clearAuth ? null : letterOfDay ?? this.letterOfDay,
  );

  /// For saving.
  Map<String, Object> toJson() => {
    if (keepZone) 'keepZone': true,
    if (noMarker) 'noMarker': true,
    if (readUnmarked) 'readUnmarked': true,
    'wipeAfter': ?wipeAfter,
    if (hasSardot) 'sardot': [sardotLat!, sardotLon!],
    'nod': ?numberOfDay,
    'lod': ?letterOfDay,
  };

  /// Reads [toJson] output; damaged values are dropped.
  static SarnegOptions fromJson(Object? json) {
    if (json is! Map) return const SarnegOptions();
    final sardot = json['sardot'];
    final ok =
        sardot is List &&
        sardot.length == 2 &&
        sardot.every((v) => v is num) &&
        validSarnegPoint(
          (sardot[0] as num).toDouble(),
          (sardot[1] as num).toDouble(),
        );
    final wipe = json['wipeAfter'];
    final nod = json['nod'];
    final lod = json['lod'];
    return SarnegOptions(
      keepZone: json['keepZone'] == true,
      noMarker: json['noMarker'] == true,
      readUnmarked: json['readUnmarked'] == true,
      wipeAfter: wipe is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(wipe)
          ? wipe
          : null,
      sardotLat: ok ? (sardot[0] as num).toDouble() : null,
      sardotLon: ok ? (sardot[1] as num).toDouble() : null,
      numberOfDay: nod is int && nod >= 0 && nod <= 99 ? nod : null,
      letterOfDay: lod is String && RegExp('^[A-Z]\$').hasMatch(lod)
          ? lod
          : null,
    );
  }
}

/// Whether [lat], [lon] is a position on Earth.
bool validSarnegPoint(double lat, double lon) =>
    lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180;

/// Reads `lat, lon` (decimal degrees) from [text]; null when there is none.
(double, double)? parseSarnegPoint(String text) {
  final m = RegExp(
    r'(?<![\d.])(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)',
  ).firstMatch(text);
  if (m == null) return null;
  final lat = double.parse(m[1]!);
  final lon = double.parse(m[2]!);
  return validSarnegPoint(lat, lon) ? (lat, lon) : null;
}

const double _earthM = 6371008.8;
double _rad(double d) => d * pi / 180;
double _deg(double r) => r * 180 / pi;

/// Bearing (degrees from true north, 0 to 359) and distance (metres) from
/// [from] to [to].
(int, double) sardotFrom((double, double) from, (double, double) to) {
  final p1 = _rad(from.$1), p2 = _rad(to.$1), dl = _rad(to.$2 - from.$2);
  final y = sin(dl) * cos(p2);
  final x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl);
  final bearing = (_deg(atan2(y, x)) + 360).round() % 360;
  final a =
      pow(sin((p2 - p1) / 2), 2) + cos(p1) * cos(p2) * pow(sin(dl / 2), 2);
  final d = 2 * _earthM * asin(min(1.0, sqrt(a.toDouble())));
  return (bearing, d);
}

/// The point [metres] away from [from] on [bearing] degrees.
(double, double) sardotTarget(
  (double, double) from,
  num bearing,
  double metres,
) {
  final p1 = _rad(from.$1), l1 = _rad(from.$2), b = _rad(bearing.toDouble());
  final dr = metres / _earthM;
  final p2 = asin(sin(p1) * cos(dr) + cos(p1) * sin(dr) * cos(b));
  final l2 =
      l1 + atan2(sin(b) * sin(dr) * cos(p1), cos(dr) - sin(p1) * sin(p2));
  return (_deg(p2), (_deg(l2) + 540) % 360 - 180);
}

/// SARDOT text for a bearing and distance: `sardot 045 2.3km`.
String sardotText(int bearing, double metres) =>
    'sardot ${bearing.toString().padLeft(3, '0')} '
    '${(metres / 1000).toStringAsFixed(metres < 10000 ? 2 : 1)}km';

/// Bearing and metres from SARDOT text in [text] (decoded); null when none.
(int, double)? parseSardot(String text) {
  final m = RegExp(
    r'sardot\s+(\d{1,3})\s+(\d+(?:\.\d+)?)\s*km',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final b = int.parse(m[1]!);
  if (b > 359) return null;
  return (b, double.parse(m[2]!) * 1000);
}

/// The position [decoded] text points at: a `lat, lon` pair, or SARDOT from
/// [reference] when one is set. Null when it holds neither.
(double, double)? sarnegPositionIn(
  String decoded, {
  (double, double)? reference,
}) {
  final dot = parseSardot(decoded);
  if (dot != null && reference != null) {
    return sardotTarget(reference, dot.$1, dot.$2);
  }
  return dot == null ? parseSarnegPoint(decoded) : null;
}

/// The reply to a number-of-the-day [challenge]: the number that adds up to
/// [numberOfDay], or null when the challenge is bigger than it.
int? sarnegReply(int numberOfDay, int challenge) =>
    challenge < 0 || challenge > numberOfDay ? null : numberOfDay - challenge;
