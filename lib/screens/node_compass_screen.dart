import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../app/compass.dart';
import '../app/position.dart';
import '../l10n/l10n.dart';
import '../presets/area_presets_provider.dart';
import 'node_details.dart' show distanceText;

/// A big arrow that points at a node, turning with the phone.
class NodeCompassScreen extends ConsumerStatefulWidget {
  const NodeCompassScreen({
    super.key,
    required this.name,
    required this.target,
  });

  final String name;
  final LatLng target;

  @override
  ConsumerState<NodeCompassScreen> createState() => _NodeCompassScreenState();
}

enum _From { phone, radio }

class _NodeCompassScreenState extends ConsumerState<NodeCompassScreen> {
  StreamSubscription<HeadingReading>? _sub;
  bool? _hasCompass;
  double? _heading; // degrees from true north, smoothed
  int _accuracy = 3;
  double _declination = 0;
  LatLng? _phone;
  bool _locating = false;
  bool _wasOnTarget = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final source = ref.read(compassSourceProvider);
    final phone = await ref.read(allowedPhonePositionProvider)();
    if (!mounted) return;
    setState(() => _phone = phone);
    final has = await source.available();
    if (!mounted) return;
    setState(() => _hasCompass = has);
    if (!has) return;
    await _updateDeclination();
    if (!mounted) return;
    _sub = source.headings().listen(
      _onHeading,
      onError: (Object _) {
        if (mounted) setState(() => _hasCompass = false);
      },
    );
  }

  Future<void> _updateDeclination() async {
    final here = _here().at;
    if (here == null) return;
    final d = await ref.read(compassSourceProvider).declination(here);
    if (mounted && d != null) setState(() => _declination = d);
  }

  void _onHeading(HeadingReading r) {
    final next = smoothHeading(_heading, r.heading + _declination);
    final at = _here().at;
    if (at != null) {
      final onTarget =
          turnDegrees(next, bearingDegrees(at, widget.target)).abs() <=
          onTargetDegrees;
      if (onTarget && !_wasOnTarget) unawaited(HapticFeedback.lightImpact());
      _wasOnTarget = onTarget;
    }
    setState(() {
      _heading = next;
      _accuracy = r.accuracy;
    });
  }

  ({LatLng? at, _From? from}) _here() {
    if (_phone != null) return (at: _phone, from: _From.phone);
    final radio = ref.read(radioPositionProvider);
    return radio == null
        ? (at: null, from: null)
        : (at: LatLng(radio.lat, radio.lon), from: _From.radio);
  }

  Future<void> _usePhone() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _locating = true);
    final here = await ref.read(phonePositionProvider)();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (here != null) _phone = here;
    });
    if (here == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.locationIsOffOrNotAllowed)),
      );
    } else {
      await _updateDeclination();
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(radioPositionProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final points = l10n.compassPoints.split(',');
    final (:at, :from) = _here();
    final heading = _heading;
    final compass = _hasCompass == true && heading != null;
    final bearing = at == null ? null : bearingDegrees(at, widget.target);
    final turn = bearing == null || !compass
        ? null
        : turnDegrees(heading, bearing);
    final distance = at == null ? null : distanceText(at, widget.target);
    final bearingText = bearing == null
        ? null
        : l10n.compassBearing(
            bearing.round() % 360,
            points[compassPointIndex(bearing)],
          );
    final turnText = turn == null
        ? null
        : turn.abs() <= onTargetDegrees
        ? l10n.compassOnTarget
        : turn < 0
        ? l10n.compassTurnLeft(turn.abs().round())
        : l10n.compassTurnRight(turn.round());
    // Rounded so a screen reader isn't told about every small wobble.
    final spokenTurn = turn == null
        ? null
        : turn.abs() <= onTargetDegrees
        ? l10n.compassOnTarget
        : turn < 0
        ? l10n.compassTurnLeft((turn.abs() / 10).round() * 10)
        : l10n.compassTurnRight((turn / 10).round() * 10);
    final rose = compass ? -heading : 0.0;
    final arrow = bearing == null ? null : bearing + rose;

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              liveRegion: true,
              label: at == null
                  ? l10n.compassNoPosition
                  : [
                      widget.name,
                      distance,
                      spokenTurn ?? bearingText,
                    ].whereType<String>().join(', '),
              child: ExcludeSemantics(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: CompassPainter(
                      roseDegrees: rose,
                      arrowDegrees: arrow,
                      onTarget: turn != null && turn.abs() <= onTargetDegrees,
                      scheme: theme.colorScheme,
                      north: points.first,
                      textStyle:
                          theme.textTheme.titleMedium ?? const TextStyle(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (at == null)
              Text(l10n.compassNoPosition, textAlign: TextAlign.center)
            else
              ExcludeSemantics(
                child: Column(
                  children: [
                    Text(distance!, style: theme.textTheme.displaySmall),
                    if (turnText != null)
                      Text(turnText, style: theme.textTheme.headlineSmall),
                    Text(bearingText!, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_hasCompass == false)
              _Note(icon: Icons.explore_off_outlined, text: l10n.compassNone),
            if (compass && _accuracy <= 1)
              _Note(icon: Icons.screen_rotation, text: l10n.compassCalibrate),
            if (from != null)
              Text(
                from == _From.phone
                    ? l10n.compassFromPhone
                    : l10n.compassFromRadio,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            if (from != _From.phone)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _usePhone,
                    icon: const Icon(Icons.my_location),
                    label: Text(l10n.compassUsePhone),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      spacing: 8,
      children: [
        Icon(icon, size: 20),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// A compass rose turned by [roseDegrees] and an arrow pointing
/// [arrowDegrees] clockwise from the top of the screen.
class CompassPainter extends CustomPainter {
  CompassPainter({
    required this.roseDegrees,
    required this.arrowDegrees,
    required this.onTarget,
    required this.scheme,
    required this.north,
    required this.textStyle,
  });

  final double roseDegrees;
  final double? arrowDegrees;
  final bool onTarget;
  final ColorScheme scheme;
  final String north;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = scheme.surfaceContainerHighest,
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = scheme.outline,
    );

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(roseDegrees * math.pi / 180);
    final tick = Paint()..color = scheme.onSurfaceVariant;
    for (var d = 0; d < 360; d += 15) {
      final long = d % 90 == 0;
      tick.strokeWidth = long ? 3 : 1.5;
      canvas.drawLine(
        Offset(0, -radius + 2),
        Offset(0, -radius + (long ? 18 : 10)),
        tick,
      );
      canvas.rotate(15 * math.pi / 180);
    }
    final label = TextPainter(
      text: TextSpan(
        text: north,
        style: textStyle.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(-label.width / 2, -radius + 22));
    canvas.restore();

    final arrow = arrowDegrees;
    if (arrow == null) return;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(arrow * math.pi / 180);
    final length = radius * 0.7;
    final shape = Path()
      ..moveTo(0, -length)
      ..lineTo(length * 0.28, length * 0.15)
      ..lineTo(0, length * 0.02)
      ..lineTo(-length * 0.28, length * 0.15)
      ..close();
    canvas.drawPath(
      shape,
      Paint()..color = onTarget ? scheme.tertiary : scheme.primary,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CompassPainter old) =>
      old.roseDegrees != roseDegrees ||
      old.arrowDegrees != arrowDegrees ||
      old.onTarget != onTarget ||
      old.scheme != scheme;
}
