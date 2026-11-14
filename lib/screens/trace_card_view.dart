import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app/repeater_test.dart' show ResponderSignal;
import '../app/trace_card.dart';
import '../l10n/l10n.dart';

/// The trace card: header, a sketch of the round trip drawn from the hops'
/// advertised positions, and every leg with its signal. Wrapped in a
/// [RepaintBoundary] keyed by [boundaryKey] so it can be saved as a picture.
class TraceCardView extends StatelessWidget {
  const TraceCardView({
    required this.card,
    required this.boundaryKey,
    super.key,
  });

  final TraceCard card;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weakest = card.weakestSnr;
    return RepaintBoundary(
      key: boundaryKey,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.traceCardTitle(card.targetName),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.traceCardFrom(
                  card.senderName,
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(card.sentAt.toLocal()),
                  ),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Fact(
                    icon: Icons.timer_outlined,
                    text: l10n.traceCardRoundTrip(
                      card.roundTrip.inMilliseconds,
                    ),
                  ),
                  _Fact(
                    icon: Icons.cell_tower,
                    text: l10n.traceCardRepeaters(card.repeaterCount),
                  ),
                  if (weakest != null)
                    _Fact(
                      icon: _signalIcon(weakest),
                      text: l10n.traceCardWeakest(
                        weakest.toStringAsFixed(1),
                        signalWord(l10n, weakest),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _Sketch(card: card),
              const SizedBox(height: 12),
              for (final leg in card.legs) _LegRow(card: card, leg: leg),
              const SizedBox(height: 8),
              Text(
                l10n.traceCardFooter,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _signalIcon(double snr) => switch (ResponderSignal.fromSnr(snr)) {
  ResponderSignal.strong => Icons.signal_cellular_alt,
  ResponderSignal.usable => Icons.signal_cellular_alt_2_bar,
  ResponderSignal.weak => Icons.signal_cellular_alt_1_bar,
};

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.card, required this.leg});

  final TraceCard card;
  final TraceCardLeg leg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final from = card.stops[leg.from].label;
    final to = card.stops[leg.to].label;
    final word = signalWord(l10n, leg.snr);
    final snr = leg.snr.toStringAsFixed(1);
    return MergeSemantics(
      child: Semantics(
        label: l10n.traceCardLegSemantics(from, to, snr, word),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                leg.returning ? Icons.south_west : Icons.north_east,
                size: 18,
              ),
              const SizedBox(width: 8),
              Icon(_signalIcon(leg.snr), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('$from → $to')),
              const SizedBox(width: 8),
              Text('${l10n.db2(snr)} · $word'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sketch extends StatelessWidget {
  const _Sketch({required this.card});

  final TraceCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final placed = card.placedStops;
    final unplaced = card.unplacedRepeaters;
    if (placed.length < 2) {
      return Text(
        l10n.traceCardNoSketch,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          image: true,
          label: l10n.traceCardSketchSemantics(
            placed.map((s) => s.hash).toSet().length,
            unplaced,
          ),
          child: ExcludeSemantics(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: CustomPaint(
                  painter: _SketchPainter(
                    stops: placed,
                    line: scheme.primary,
                    dot: scheme.onSurface,
                    self: scheme.tertiary,
                    text: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (unplaced > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.traceCardUnplaced(unplaced),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({
    required this.stops,
    required this.line,
    required this.dot,
    required this.self,
    required this.text,
  });

  final List<TraceStop> stops;
  final Color line;
  final Color dot;
  final Color self;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    final points = sketchPoints(stops, size.width, size.height, pad: 24);
    if (points.isEmpty) return;
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final p in points.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    canvas.drawPath(path, stroke);
    final labelled = <String>{};
    for (var i = 0; i < points.length; i++) {
      final stop = stops[i];
      final o = Offset(points[i].x, points[i].y);
      if (stop.isSelf) {
        // A square for this radio, so it doesn't rely on colour alone.
        canvas.drawRect(
          Rect.fromCenter(center: o, width: 12, height: 12),
          Paint()..color = self,
        );
      } else {
        canvas.drawCircle(o, 6, Paint()..color = dot);
      }
      if (!labelled.add(stop.hash)) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: stop.label,
          style: TextStyle(color: text, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width / 3);
      painter.paint(canvas, o + const Offset(8, -14));
    }
  }

  @override
  bool shouldRepaint(_SketchPainter old) =>
      old.stops != stops || old.line != line || old.dot != dot;
}

/// Renders the card behind [boundaryKey] to PNG bytes, or null if it isn't
/// on screen.
Future<Uint8List?> traceCardPng(GlobalKey boundaryKey) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}
