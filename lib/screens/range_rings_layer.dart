import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/range_rings.dart';
import '../l10n/l10n.dart';

/// Four distance rings around [centre], sized to the part of the map that
/// [obscured] leaves visible, with a label on each ring's north point,
/// faint spokes every 45° and the compass letters just outside the outer
/// ring. Labels are kept inside the visible part, clear of the toolbar.
/// Drawn in screen pixels so labels sit exactly on the rings at any zoom.
/// Ignores taps, so markers underneath still work.
class RangeRingsLayer extends StatelessWidget {
  const RangeRingsLayer({
    required this.centre,
    required this.unit,
    this.obscured = EdgeInsets.zero,
    super.key,
  });

  final LatLng centre;
  final DistanceUnit unit;

  /// How much of each edge of the map other controls cover.
  final EdgeInsets obscured;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final size = camera.nonRotatedSize;
    final full = Offset.zero & size;
    final visible = obscured.deflateRect(full);
    final area = visible.isEmpty ? full : visible;

    // Metres per pixel in the middle of the visible part, measured the way
    // the rings are drawn (southwards), sets the spacing.
    final mid = area.center;
    final midAt = camera.screenOffsetToLatLng(mid);
    const probe = 100.0;
    final perPixel =
        metresBetween(
          midAt,
          camera.screenOffsetToLatLng(mid + const Offset(0, probe)),
        ) /
        probe;
    final radii = ringRadii(ringReachPixels(area) * perPixel, unit);

    final origin = camera.latLngToScreenOffset(centre);
    double pixels(double metres) =>
        (camera.latLngToScreenOffset(pointAt(centre, metres, 180)) - origin)
            .distance;
    final ringPixels = [for (final r in radii) pixels(r)];
    final outer = ringPixels.last;
    // Screen directions of the eight bearings, so spokes and letters stay
    // true when the map is turned.
    final directions = [
      for (var b = 0; b < 360; b += 45)
        _unit(
          camera.latLngToScreenOffset(
                pointAt(centre, radii.last, b.toDouble()),
              ) -
              origin,
          b,
        ),
    ];

    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: scheme.onSurface);
    final scaler = MediaQuery.textScalerOf(context);
    final points = context.l10n.compassPoints.split(',');
    String letter(int quarter) => points.length == 8
        ? points[quarter * 2]
        : const ['N', 'E', 'S', 'W'][quarter];

    // Compass letters first: they matter most when room runs out.
    final texts = <String>[
      for (var q = 0; q < 4; q++) letter(q),
      for (final r in radii) ringLabel(r, unit),
    ];
    final anchors = <Offset>[
      for (var q = 0; q < 4; q++) origin + directions[q * 2] * (outer + 22),
      for (final r in ringPixels) origin + directions[0] * r,
    ];
    final boxes = [
      for (var i = 0; i < texts.length; i++)
        Rect.fromCenter(
          center: anchors[i],
          width: _measure(texts[i], style, scaler).width + 8,
          height: _measure(texts[i], style, scaler).height + 2,
        ),
    ];
    final placed = placeLabels(boxes, area);

    return IgnorePointer(
      child: Semantics(
        label: context.l10n.rangeRingsSpoken(
          radii.map((r) => ringLabel(r, unit)).join(', '),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RingsPainter(
                origin: origin,
                rings: ringPixels,
                directions: directions,
                colour: scheme.primary,
              ),
            ),
            for (var i = 0; i < texts.length; i++)
              if (placed[i] case final box?)
                Positioned.fromRect(
                  rect: box,
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          texts[i],
                          style: style,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// [v] scaled to length 1, or the plain screen direction for [bearing]
  /// when it has no length (a ring too small to measure).
  static Offset _unit(Offset v, int bearing) {
    if (v.distance > 1e-6) return v / v.distance;
    final a = bearing * math.pi / 180;
    return Offset(math.sin(a), -math.cos(a));
  }

  static Size _measure(String text, TextStyle? style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.origin,
    required this.rings,
    required this.directions,
    required this.colour,
  });

  final Offset origin;
  final List<double> rings;
  final List<Offset> directions;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colour.withValues(alpha: 0.7);
    final spoke = Paint()
      ..strokeWidth = 1
      ..color = colour.withValues(alpha: 0.25);
    final outer = rings.last;
    for (final d in directions) {
      canvas.drawLine(origin, origin + d * outer, spoke);
    }
    for (final r in rings) {
      canvas.drawCircle(origin, r, ring);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.origin != origin ||
      old.colour != colour ||
      !_same(old.rings, rings) ||
      !_same(old.directions, directions);

  static bool _same<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
