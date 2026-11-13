import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/path_graph.dart';

/// Where each dot of a [PathNetwork] goes.
class NetworkLayout {
  const NetworkLayout(
    this.centers,
    this.radii,
    this.center,
    this.gap,
    this.rings,
  );

  final Map<String, Offset> centers;
  final Map<String, double> radii;
  final Offset center;
  final double gap;
  final int rings;

  /// The dot under [p], allowing a finger-sized margin.
  String? hit(Offset p, {double slop = 16}) {
    String? best;
    var bestD = double.infinity;
    for (final e in centers.entries) {
      final d = (e.value - p).distance;
      if (d <= radii[e.key]! + slop && d < bestD) {
        best = e.key;
        bestD = d;
      }
    }
    return best;
  }
}

/// You in the middle, repeaters on rings by hops. Rings after the first
/// are ordered by where their links sit on the ring inside, so lines cross
/// less.
NetworkLayout layoutNetwork(PathNetwork net, Size size) {
  final rings = net.nodes.values.fold(0, (m, n) => math.max(m, n.ring));
  final center = Offset(size.width / 2, size.height / 2);
  final maxR = math.max(0.0, math.min(size.width, size.height) / 2 - 18);
  final gap = rings == 0 ? 0.0 : maxR / rings;
  final most = net.nodes.values.fold(1, (m, n) => math.max(m, n.relayed));
  final near = <String, Map<String, int>>{};
  for (final e in net.links.entries) {
    (near[e.key.$1] ??= {})[e.key.$2] = e.value;
    (near[e.key.$2] ??= {})[e.key.$1] = e.value;
  }
  final angle = <String, double>{networkSelf: 0};
  final centers = <String, Offset>{networkSelf: center};
  final radii = <String, double>{networkSelf: 11};
  for (var r = 1; r <= rings; r++) {
    final ids = [
      for (final e in net.nodes.entries)
        if (e.value.ring == r) e.key,
    ]..sort((a, b) => net.nodes[b]!.relayed.compareTo(net.nodes[a]!.relayed));
    if (r > 1) {
      double score(String id) {
        var x = 0.0, y = 0.0;
        for (final e in (near[id] ?? const <String, int>{}).entries) {
          final a = angle[e.key];
          if (a == null) continue;
          x += math.cos(a) * e.value;
          y += math.sin(a) * e.value;
        }
        if (x == 0 && y == 0) return double.infinity;
        final a = math.atan2(y, x);
        return a < 0 ? a + 2 * math.pi : a;
      }

      final s = {for (final id in ids) id: score(id)};
      ids.sort((a, b) => s[a]!.compareTo(s[b]!));
    }
    for (var i = 0; i < ids.length; i++) {
      final a =
          -math.pi / 2 + (i + (r.isEven ? .5 : 0)) * 2 * math.pi / ids.length;
      angle[ids[i]] = a < 0 ? a + 2 * math.pi : a;
      centers[ids[i]] =
          center + Offset(math.cos(a) * gap * r, math.sin(a) * gap * r);
      radii[ids[i]] = 4 + 6 * math.sqrt(net.nodes[ids[i]]!.relayed / most);
    }
  }
  return NetworkLayout(centers, radii, center, gap, rings);
}

/// Draws [layout]: faint rings, lines as thick as their traffic, dots as
/// big as how much each repeater relayed, and labels on the busiest.
class NetworkPainter extends CustomPainter {
  NetworkPainter({
    required this.net,
    required this.layout,
    required this.scheme,
    required this.labelStyle,
    required this.label,
  });

  final PathNetwork net;
  final NetworkLayout layout;
  final ColorScheme scheme;
  final TextStyle labelStyle;
  final String Function(String id) label;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = scheme.outlineVariant.withValues(alpha: .6);
    for (var i = 1; i <= layout.rings; i++) {
      canvas.drawCircle(layout.center, layout.gap * i, ring);
    }
    final most = net.links.values.fold(1, math.max);
    final links = net.links.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in links) {
      final f = e.value / most;
      canvas.drawLine(
        layout.centers[e.key.$1]!,
        layout.centers[e.key.$2]!,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1 + 4 * f
          ..color = scheme.primary.withValues(alpha: .25 + .55 * f),
      );
    }
    for (final id in net.nodes.keys) {
      final c = layout.centers[id]!, r = layout.radii[id]!;
      canvas.drawCircle(
        c,
        r,
        Paint()..color = id == networkSelf ? scheme.tertiary : scheme.primary,
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = scheme.surface,
      );
    }
    final busiest = net.nodes.keys.where((id) => id != networkSelf).toList()
      ..sort((a, b) => net.nodes[b]!.relayed.compareTo(net.nodes[a]!.relayed));
    for (final id in [networkSelf, ...busiest.take(12)]) {
      final tp = TextPainter(
        text: TextSpan(text: label(id), style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 110);
      final c = layout.centers[id]!, r = layout.radii[id]!;
      final dx = (c.dx - tp.width / 2)
          .clamp(2.0, math.max(2.0, size.width - tp.width - 2))
          .toDouble();
      var dy = c.dy + r + 2;
      if (dy + tp.height > size.height) dy = c.dy - r - tp.height - 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx - 3, dy - 1, tp.width + 6, tp.height + 2),
          const Radius.circular(4),
        ),
        Paint()..color = scheme.surface.withValues(alpha: .85),
      );
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(NetworkPainter old) =>
      old.net != net || old.scheme != scheme;
}
