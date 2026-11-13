/// A shareable summary of one finished trace: who sent it, when, how long
/// the round trip took, and every hop with the signal it was heard at.
/// The card is built from the trace reply alone plus what the app already
/// knows about the hops (names and advertised positions), so it works
/// offline and can be shared as text or as a picture.
library;

import 'dart:math' as math;

import '../data/data.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';
import 'repeater_test.dart' show ResponderSignal;

/// One place the trace passed through. The first and last stops are this
/// radio; the rest are repeaters named by their hash.
typedef TraceStop = ({
  /// Contact name, or the hop's hash in capitals when nobody matches.
  String label,

  /// The hop's hash in hex, or empty for this radio.
  String hash,

  /// Whether this stop is this radio (start and end of the round trip).
  bool isSelf,

  /// Advertised position, when known.
  double? latitude,
  double? longitude,
});

/// One leg of the round trip: from one stop to the next, and how well
/// the next stop heard it.
typedef TraceCardLeg = ({int from, int to, double snr, bool returning});

/// Everything a trace card shows.
class TraceCard {
  TraceCard({
    required this.senderName,
    required this.targetName,
    required this.sentAt,
    required this.roundTrip,
    required this.stops,
    required this.legs,
  });

  /// Builds a card from a returned [trace]. [contacts] name the hops and
  /// give their positions; [self] is this radio's own info.
  factory TraceCard.fromTrace({
    required TraceData trace,
    required List<Contact> contacts,
    required String senderName,
    required String targetName,
    required DateTime sentAt,
    required DateTime returnedAt,
    double? selfLatitude,
    double? selfLongitude,
  }) {
    final self = (
      label: senderName,
      hash: '',
      isSelf: true,
      latitude: selfLatitude,
      longitude: selfLongitude,
    );
    TraceStop hop(int i) {
      final hex = toHex(
        trace.hashes.sublist(i * trace.hashBytes, (i + 1) * trace.hashBytes),
      );
      final match = contacts.where((c) => c.publicKey.startsWith(hex));
      final contact = match.isEmpty ? null : match.first;
      return (
        label: contact?.name ?? hex.toUpperCase(),
        hash: hex,
        isSelf: false,
        latitude: _usable(contact?.latitude, contact?.longitude)
            ? contact!.latitude
            : null,
        longitude: _usable(contact?.latitude, contact?.longitude)
            ? contact!.longitude
            : null,
      );
    }

    final count = trace.snrs.length;
    final stops = <TraceStop>[self, for (var i = 0; i < count; i++) hop(i)];
    if (count > 0) stops.add(self);
    final turn = (count + 1) / 2;
    final legs = <TraceCardLeg>[
      for (var i = 0; i < count; i++)
        (from: i, to: i + 1, snr: trace.snrs[i], returning: i + 1 > turn),
      if (count > 0)
        (from: count, to: count + 1, snr: trace.finalSnr, returning: true),
    ];
    final elapsed = returnedAt.difference(sentAt);
    return TraceCard(
      senderName: senderName,
      targetName: targetName,
      sentAt: sentAt,
      roundTrip: elapsed.isNegative ? Duration.zero : elapsed,
      stops: stops,
      legs: legs,
    );
  }

  final String senderName;
  final String targetName;
  final DateTime sentAt;
  final Duration roundTrip;
  final List<TraceStop> stops;
  final List<TraceCardLeg> legs;

  /// Distinct repeaters the trace went through.
  int get repeaterCount =>
      stops.where((s) => !s.isSelf).map((s) => s.hash).toSet().length;

  /// The weakest leg, which limits the whole route. Null for no legs.
  double? get weakestSnr =>
      legs.isEmpty ? null : legs.map((l) => l.snr).reduce(math.min);

  /// Stops that have a position, in route order, for drawing a sketch.
  List<TraceStop> get placedStops =>
      stops.where((s) => s.latitude != null && s.longitude != null).toList();

  /// Repeaters without a known position: listed but not drawn.
  int get unplacedRepeaters => stops
      .where((s) => !s.isSelf && (s.latitude == null || s.longitude == null))
      .map((s) => s.hash)
      .toSet()
      .length;

  /// Plain text for sharing, in the user's language.
  String toText(AppLocalizations l10n) {
    final out = StringBuffer()
      ..writeln(l10n.traceCardTitle(targetName))
      ..writeln(l10n.traceCardFrom(senderName, _stamp(sentAt)))
      ..writeln(
        l10n.traceCardSummary(
          roundTrip.inMilliseconds,
          repeaterCount,
          weakestSnr?.toStringAsFixed(1) ?? '-',
        ),
      );
    for (final leg in legs) {
      out.writeln(
        '${stops[leg.from].label} → ${stops[leg.to].label}: '
        '${l10n.db2(leg.snr.toStringAsFixed(1))} '
        '(${signalWord(l10n, leg.snr)})',
      );
    }
    for (final s in stops.where((s) => s.latitude != null)) {
      if (s.isSelf && s != stops.first) continue;
      out.writeln(
        '${s.label}: ${s.latitude!.toStringAsFixed(5)}, '
        '${s.longitude!.toStringAsFixed(5)}',
      );
    }
    out.write(l10n.traceCardFooter);
    return out.toString();
  }
}

/// Strong / Usable / Weak for a leg, in words so colour isn't the only cue.
String signalWord(AppLocalizations l10n, double snr) =>
    switch (ResponderSignal.fromSnr(snr)) {
      ResponderSignal.strong => l10n.signalStrong,
      ResponderSignal.usable => l10n.signalUsable,
      ResponderSignal.weak => l10n.signalWeak,
    };

bool _usable(double? lat, double? lon) =>
    lat != null &&
    lon != null &&
    !(lat == 0 && lon == 0) &&
    lat.abs() <= 90 &&
    lon.abs() <= 180;

String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final l = t.toLocal();
  return '${l.year}-${two(l.month)}-${two(l.day)} '
      '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

/// Projects [stops] onto a [width] × [height] box with [pad] margins,
/// keeping north up and the same scale on both axes. Returns one point
/// per stop, or an empty list when fewer than two stops are placed.
List<math.Point<double>> sketchPoints(
  List<TraceStop> stops,
  double width,
  double height, {
  double pad = 16,
}) {
  final placed = stops.where((s) => s.latitude != null).toList();
  if (placed.length < 2) return const [];
  final midLat =
      placed.map((s) => s.latitude!).reduce((a, b) => a + b) / placed.length;
  final shrink = math.cos(midLat * math.pi / 180);
  final xs = [for (final s in placed) s.longitude! * shrink];
  final ys = [for (final s in placed) -s.latitude!];
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final spanX = math.max(maxX - minX, 1e-9);
  final spanY = math.max(maxY - minY, 1e-9);
  final scale = math.min((width - 2 * pad) / spanX, (height - 2 * pad) / spanY);
  final offX = (width - spanX * scale) / 2;
  final offY = (height - spanY * scale) / 2;
  return [
    for (var i = 0; i < placed.length; i++)
      math.Point(offX + (xs[i] - minX) * scale, offY + (ys[i] - minY) * scale),
  ];
}
