import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/traffic.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';

/// Draws the routes in [trafficProvider] on the map, hop by hop. Goes in a
/// [FlutterMap]'s children, above the tiles and below the markers.
class TrafficLayer extends ConsumerStatefulWidget {
  const TrafficLayer({super.key});

  @override
  ConsumerState<TrafficLayer> createState() => _TrafficLayerState();
}

class _TrafficLayerState extends ConsumerState<TrafficLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _now = Duration.zero;
  bool _reduceMotion = false;

  void _tick(Duration elapsed) {
    _now = elapsed;
    final traffic = ref.read(trafficProvider.notifier);
    traffic.advance(elapsed, reduceMotion: _reduceMotion);
    if (!ref.read(trafficProvider).busy) {
      _ticker.stop();
      _now = Duration.zero;
    }
    setState(() {});
  }

  void _wake(TrafficState state) {
    if (state.busy && !_ticker.isActive) unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    ref.listen(trafficProvider, (_, next) => _wake(next));
    final state = ref.watch(trafficProvider);
    if (!state.on) return const SizedBox.shrink();
    _wake(state);
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrafficPainter(
          routes: [
            for (final a in state.active)
              _PlacedRoute(
                kind: a.route.kind,
                points: [
                  for (final p in a.route.points)
                    camera.latLngToScreenOffset(p),
                ],
                labels: [
                  for (final s in a.route.stops)
                    if (s.at != null) s.label,
                ],
                elapsed: _now - a.start,
                travel: trafficTravelTime(a.route, reduceMotion: _reduceMotion),
              ),
          ],
          reduceMotion: _reduceMotion,
          labelStyle: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _PlacedRoute {
  const _PlacedRoute({
    required this.kind,
    required this.points,
    required this.labels,
    required this.elapsed,
    required this.travel,
  });

  final TrafficKind kind;
  final List<Offset> points;
  final List<String> labels;
  final Duration elapsed;
  final Duration travel;
}

class _TrafficPainter extends CustomPainter {
  _TrafficPainter({
    required this.routes,
    required this.reduceMotion,
    required this.labelStyle,
  });

  final List<_PlacedRoute> routes;
  final bool reduceMotion;
  final TextStyle? labelStyle;

  static const _pulse = Duration(milliseconds: 1200);

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in routes) {
      _paintRoute(canvas, r);
    }
  }

  void _paintRoute(Canvas canvas, _PlacedRoute r) {
    if (r.points.isEmpty) return;
    final colour = r.kind.colour;
    final t = r.elapsed.inMicroseconds.toDouble();
    final travel = r.travel.inMicroseconds.toDouble();
    final fade = trafficFadeTime.inMicroseconds.toDouble();
    final opacity = t <= travel
        ? 1.0
        : (1 - (t - travel) / fade).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final legs = r.points.length - 1;
    // How far along the route the dot is, in legs.
    final progress = travel == 0 ? legs.toDouble() : legs * (t / travel);
    final line = Paint()
      ..color = colour.withValues(alpha: 0.85 * opacity)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final glow = Paint()
      ..color = colour.withValues(alpha: 0.35 * opacity)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (var i = 0; i < legs; i++) {
      final a = r.points[i];
      final b = r.points[i + 1];
      if (i + 1 <= progress) {
        canvas
          ..drawLine(a, b, glow)
          ..drawLine(a, b, line);
      } else if (i < progress) {
        final head = Offset.lerp(a, b, progress - i)!;
        canvas
          ..drawLine(a, head, glow)
          ..drawLine(a, head, line);
        _dotted(canvas, head, b, line);
      } else {
        _dotted(canvas, a, b, line);
      }
    }

    // A ring pulses at the origin as it sets off, and at the end as it
    // arrives. With reduced motion the rings hold still.
    _ring(canvas, r.points.first, colour, t / _pulse.inMicroseconds, opacity);
    if (t >= travel) {
      _ring(
        canvas,
        r.points.last,
        colour,
        (t - travel) / _pulse.inMicroseconds,
        opacity,
      );
    }

    if (!reduceMotion && legs > 0 && progress < legs) {
      final leg = progress.floor().clamp(0, legs - 1);
      final dot = Offset.lerp(
        r.points[leg],
        r.points[leg + 1],
        progress - leg,
      )!;
      canvas
        ..drawCircle(
          dot,
          10,
          Paint()
            ..color = colour.withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        )
        ..drawCircle(dot, 5, Paint()..color = colour)
        ..drawCircle(dot, 2.5, Paint()..color = Colors.white);
    }

    _labels(canvas, r, opacity);
  }

  void _dotted(Canvas canvas, Offset a, Offset b, Paint line) {
    final length = (b - a).distance;
    if (length == 0) return;
    final dots = Paint()
      ..color = line.color.withValues(alpha: line.color.a * 0.7)
      ..style = PaintingStyle.fill;
    const gap = 7.0;
    for (var d = 0.0; d <= length; d += gap) {
      canvas.drawCircle(Offset.lerp(a, b, d / length)!, 1.4, dots);
    }
  }

  void _ring(
    Canvas canvas,
    Offset at,
    Color colour,
    double cycles,
    double opacity,
  ) {
    final phase = reduceMotion ? 0.5 : cycles % 1;
    // Two pulses, then the ring settles.
    if (!reduceMotion && cycles > 2) return;
    final radius = 8 + 22 * phase;
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colour.withValues(alpha: (1 - phase) * 0.8 * opacity),
    );
  }

  void _labels(Canvas canvas, _PlacedRoute r, double opacity) {
    final style = (labelStyle ?? const TextStyle(fontSize: 11)).copyWith(
      color: Colors.white.withValues(alpha: opacity),
      shadows: const [Shadow(blurRadius: 3)],
    );
    for (var i = 0; i < r.points.length && i < r.labels.length; i++) {
      final text = TextPainter(
        text: TextSpan(text: r.labels[i], style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 120);
      text.paint(canvas, r.points[i] + const Offset(10, -18));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_TrafficPainter old) => true;
}

/// The frosted panel used for the route card and the map toolbar.
class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    required this.child,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The name of [kind] in the legend.
String trafficKindLabel(BuildContext context, TrafficKind kind) =>
    switch (kind) {
      TrafficKind.advert => context.l10n.trafficAdvert,
      TrafficKind.direct => context.l10n.trafficDirectMessage,
      TrafficKind.channel => context.l10n.trafficChannelMessage,
      TrafficKind.ack => context.l10n.trafficAcknowledgement,
      TrafficKind.trace => context.l10n.trafficTrace,
      TrafficKind.path => context.l10n.trafficPath,
    };

/// The newest route as text, with the colour legend under it. Tap for the
/// packet log.
class TrafficRouteCard extends ConsumerStatefulWidget {
  const TrafficRouteCard({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  ConsumerState<TrafficRouteCard> createState() => _TrafficRouteCardState();
}

class _TrafficRouteCardState extends ConsumerState<TrafficRouteCard> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keeps the age current.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final route = ref.watch(trafficProvider).latest;
    return Semantics(
      container: true,
      button: widget.onTap != null,
      child: GestureDetector(
        key: const Key('traffic-card'),
        onTap: widget.onTap,
        child: FrostedPanel(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (route == null)
                Text(l10n.trafficListening, style: theme.textTheme.titleSmall)
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    route.summary,
                    key: const Key('traffic-route'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TypePill(route: route),
                    Text(
                      route.heardFrom == null
                          ? l10n.trafficSnr(route.snr.toStringAsFixed(2))
                          : l10n.trafficHeardFrom(
                              route.heardFrom!.label,
                              route.snr.toStringAsFixed(2),
                            ),
                      style: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_details(context, route), style: muted),
                if (route.offMap.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 14,
                        color: muted?.color,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          l10n.trafficNotOnMapNames(
                            route.offMap.map((s) => s.label).join(', '),
                          ),
                          style: muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 10),
              const TrafficLegend(),
            ],
          ),
        ),
      ),
    );
  }

  String _details(BuildContext context, TrafficRoute route) {
    final l10n = context.l10n;
    final age = DateTime.now().difference(route.heardAt).inSeconds;
    return [
      route.isFlood
          ? l10n.trafficFlood(route.hopCount)
          : l10n.trafficDirect(route.hopCount),
      l10n.trafficRssi(route.rssi),
      l10n.trafficSnrShort(route.snr.toStringAsFixed(2)),
      l10n.trafficNotOnMapCount(route.offMap.length),
      l10n.trafficAge(math.max(0, age)),
    ].join(' · ');
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.route});

  final TrafficRoute route;

  @override
  Widget build(BuildContext context) {
    final colour = route.kind.colour;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour),
      ),
      child: Text(
        payloadKindLabel(context, route.payload),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The pill text for [payload].
String payloadKindLabel(BuildContext context, PayloadKind payload) {
  final l10n = context.l10n;
  return switch (payload) {
    PayloadKind.request => l10n.trafficRequest,
    PayloadKind.response => l10n.trafficResponse,
    PayloadKind.text => l10n.trafficDirectMessage,
    PayloadKind.ack => l10n.trafficAcknowledgement,
    PayloadKind.advert => l10n.trafficAdvert,
    PayloadKind.groupText ||
    PayloadKind.groupData => l10n.trafficChannelMessage,
    PayloadKind.anonRequest => l10n.trafficLogin,
    PayloadKind.path => l10n.trafficPath,
    PayloadKind.trace => l10n.trafficTrace,
    _ => l10n.trafficOther,
  };
}

/// A dot and name for each of the six colours.
class TrafficLegend extends StatelessWidget {
  const TrafficLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final kind in TrafficKind.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                  color: kind.colour,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(trafficKindLabel(context, kind), style: style),
            ],
          ),
      ],
    );
  }
}

/// Picks which kinds of packet the traffic layer draws.
Future<void> showTrafficFilter(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final shown = ref.watch(trafficProvider).shown;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(title: Text(context.l10n.trafficShowPackets)),
                for (final kind in TrafficKind.values)
                  CheckboxListTile(
                    key: Key('traffic-filter-${kind.name}'),
                    value: shown.contains(kind),
                    secondary: Icon(Icons.circle, color: kind.colour, size: 16),
                    title: Text(trafficKindLabel(context, kind)),
                    onChanged: (on) => ref
                        .read(trafficProvider.notifier)
                        .setShown(
                          on == true
                              ? {...shown, kind}
                              : ({...shown}..remove(kind)),
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
