/// Bot commands: `!ping`, `!trace`, `!sun`, `!moon`, `!dice` and `!help`.
/// Everything is worked out on the phone; nothing goes to the internet.
library;

import 'dart:math' as math;

/// Sunrise and sunset in UTC at [lat], [lon] on [day]'s date. Null for a
/// time that doesn't happen that day (polar day or night). The usual
/// almanac method, good to a few minutes.
({DateTime? rise, DateTime? set}) sunTimes(
  DateTime day,
  double lat,
  double lon,
) {
  final n = day.difference(DateTime.utc(day.year)).inDays + 1;
  double rad(double d) => d * math.pi / 180;
  double deg(double r) => r * 180 / math.pi;
  DateTime? at(bool rising) {
    final lngHour = lon / 15;
    final t = n + ((rising ? 6 : 18) - lngHour) / 24;
    final m = 0.9856 * t - 3.289;
    final l =
        (m +
            1.916 * math.sin(rad(m)) +
            0.020 * math.sin(rad(2 * m)) +
            282.634) %
        360;
    var ra = deg(math.atan(0.91764 * math.tan(rad(l)))) % 360;
    ra += (l / 90).floor() * 90 - (ra / 90).floor() * 90;
    ra /= 15;
    final sinDec = 0.39782 * math.sin(rad(l));
    final cosDec = math.cos(math.asin(sinDec));
    final cosH =
        (math.cos(rad(90.833)) - sinDec * math.sin(rad(lat))) /
        (cosDec * math.cos(rad(lat)));
    if (cosH > 1 || cosH < -1) return null;
    final h = (rising ? 360 - deg(math.acos(cosH)) : deg(math.acos(cosH))) / 15;
    final ut = (h + ra - 0.06571 * t - 6.622 - lngHour) % 24;
    final start = DateTime.utc(day.year, day.month, day.day);
    return start.add(Duration(seconds: (ut * 3600).round()));
  }

  return (rise: at(true), set: at(false));
}

/// How far through its cycle the moon is at [t]: 0 new, 0.5 full.
double moonPhase(DateTime t) {
  const synodic = 29.530588853;
  final known = DateTime.utc(2000, 1, 6, 18, 14); // a new moon
  final days = t.toUtc().difference(known).inSeconds / 86400;
  return (days / synodic) % 1;
}

String moonText(DateTime t) {
  final p = moonPhase(t);
  final lit = ((1 - math.cos(2 * math.pi * p)) / 2 * 100).round();
  const names = [
    ('🌑', 'New moon'),
    ('🌒', 'Waxing crescent'),
    ('🌓', 'First quarter'),
    ('🌔', 'Waxing gibbous'),
    ('🌕', 'Full moon'),
    ('🌖', 'Waning gibbous'),
    ('🌗', 'Last quarter'),
    ('🌘', 'Waning crescent'),
  ];
  final (icon, name) = names[((p * 8) + 0.5).floor() % 8];
  return '$icon $name, $lit% lit';
}

/// "3d6" style dice, at most 10 dice of up to 1000 sides. Null if [spec]
/// isn't dice.
String? diceText(String spec, math.Random rng) {
  final m = RegExp(r'^(\d{0,2})d(\d{1,4})$').firstMatch(spec.toLowerCase());
  final count = m == null ? 1 : int.parse(m[1]!.isEmpty ? '1' : m[1]!);
  final sides = m == null ? 6 : int.parse(m[2]!);
  if (spec.isNotEmpty && m == null) return null;
  if (count < 1 || count > 10 || sides < 2 || sides > 1000) return null;
  final rolls = [for (var i = 0; i < count; i++) rng.nextInt(sides) + 1];
  final total = rolls.fold(0, (a, b) => a + b);
  return count == 1
      ? '🎲 $total (d$sides)'
      : '🎲 $total (${rolls.join(' + ')})';
}

/// How a message arrived, for `!ping` and `!trace`.
String routeText({required int? pathLength, required double? snr}) {
  final hops = pathLength == null || pathLength == 0xFF
      ? null
      : pathLength & 0x3F;
  final how = hops == null
      ? 'came direct'
      : hops == 0
      ? 'came straight to my radio'
      : 'came through $hops repeater${hops == 1 ? '' : 's'}';
  final signal = snr == null ? '' : ', last hop ${snr.toStringAsFixed(1)} dB';
  return 'Your message $how$signal.';
}

const botCommandNames = ['ping', 'trace', 'sun', 'moon', 'dice', 'help'];

/// The reply to a `!command` in [body], or null if it isn't one this bot
/// answers.
String? botCommandReply(
  String body, {
  required int? pathLength,
  required double? snr,
  required DateTime now,
  ({double lat, double lon})? position,
  math.Random? random,
}) {
  final words = body.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || !words.first.startsWith('!')) return null;
  final arg = words.length > 1 ? words[1] : '';
  String two(int v) => v.toString().padLeft(2, '0');
  String clock(DateTime t) {
    final l = t.toLocal();
    return '${two(l.hour)}:${two(l.minute)}';
  }

  switch (words.first.substring(1).toLowerCase()) {
    case 'ping':
      return 'pong. ${routeText(pathLength: pathLength, snr: snr)}';
    case 'trace':
      return routeText(pathLength: pathLength, snr: snr);
    case 'sun':
      if (position == null) return 'My radio has no position set.';
      final s = sunTimes(now.toUtc(), position.lat, position.lon);
      return 'Sunrise ${s.rise == null ? '—' : clock(s.rise!)}, '
          'sunset ${s.set == null ? '—' : clock(s.set!)} (my time).';
    case 'moon':
      return moonText(now);
    case 'dice':
    case 'roll':
      return diceText(arg, random ?? math.Random());
    case 'help':
      return 'Commands: ${botCommandNames.map((c) => '!$c').join(' ')}';
    default:
      return null;
  }
}
