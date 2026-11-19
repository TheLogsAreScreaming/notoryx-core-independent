import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/range_rings.dart';
import '../l10n/l10n.dart';

/// Four distance rings around [centre], sized to the visible map, with a
/// label on each ring's north point, faint spokes every 45° and the
/// compass letters just outside the outer ring. Ignores taps, so markers
/// underneath still work.
///
/// While [centre] is on screen, the rings are sized so that the outer
/// ring and its compass letters stay inside the map, clear of [covered]
/// (the map's own buttons and cards on top of it).
class RangeRingsLayer extends StatelessWidget {
  const RangeRingsLayer({
    required this.centre,
    required this.unit,
    this.covered = EdgeInsets.zero,
    super.key,
  });

  final LatLng centre;
  final DistanceUnit unit;

  /// How much of each side of the map is hidden behind other widgets.
  final EdgeInsets covered;

  /// The smallest outer radius in pixels. Near a card or the toolbar the
  /// clear room can be tiny; the rings stay at least this big rather than
  /// jumping back to the size of the whole view.
  static const _smallest = 48.0;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final view = camera.visibleBounds;
    final at = camera.latLngToScreenOffset(centre);
    // The map as it is on screen; [MapCamera.size] is the larger box
    // around a rotated map.
    final size = camera.nonRotatedSize;
    final onScreen = clearRoom(at, size) >= 0;
    final room = math.max(
      ringRoomPx(
        clearRoom(
          at,
          size,
          left: covered.left,
          top: covered.top,
          right: covered.right,
          bottom: covered.bottom,
        ),
      ),
      _smallest,
    );
    // Sized to the clear room around the centre while it's on screen;
    // sized to the whole view only when the centre is off it.
    final reach = onScreen
        ? [
            for (final d in const [
              Offset(0, -1),
              Offset(1, 0),
              Offset(0, 1),
              Offset(-1, 0),
            ])
              metresBetween(centre, camera.screenOffsetToLatLng(at + d * room)),
          ].reduce(math.min)
        : viewReach(
            camera.center,
            north: view.north,
            south: view.south,
            east: view.east,
            west: view.west,
          );
    final radii = ringRadii(reach, unit);
    final outer = radii.last;
    final stepPx =
        (camera.latLngToScreenOffset(pointAt(centre, radii.first, 0)) - at)
            .distance;
    final labelled = labelledRings(stepPx, count: radii.length);
    // The compass letters, in metres from the centre.
    final metresPerPx = stepPx > 0 ? radii.first / stepPx : 0.0;
    final outerPx = outer / (metresPerPx > 0 ? metresPerPx : 1);
    final compass = metresPerPx > 0
        ? outer + compassGapPx(outerPx) * metresPerPx
        : outer * compassTagFactor;
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.primary;
    final textStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: scheme.onSurface);
    final points = context.l10n.compassPoints.split(',');
    String letter(int index) => points.length == 8
        ? points[index]
        : const ['N', 'E', 'S', 'W'][index ~/ 2];

    Widget chip(String text) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: textStyle, maxLines: 1),
      ),
    );

    return IgnorePointer(
      child: Semantics(
        label: context.l10n.rangeRingsSpoken(
          radii.map((r) => ringLabel(r, unit)).join(', '),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PolylineLayer(
              polylines: [
                for (var bearing = 0; bearing < 360; bearing += 45)
                  Polyline(
                    points: [
                      centre,
                      pointAt(centre, outer, bearing.toDouble()),
                    ],
                    strokeWidth: 1,
                    color: line.withValues(alpha: 0.25),
                  ),
              ],
            ),
            CircleLayer(
              circles: [
                for (final r in radii)
                  CircleMarker(
                    point: centre,
                    radius: r,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: line.withValues(alpha: 0.7),
                    borderStrokeWidth: 1.5,
                  ),
              ],
            ),
            ExcludeSemantics(
              child: MarkerLayer(
                markers: [
                  for (final i in labelled)
                    Marker(
                      point: pointAt(centre, radii[i], 0),
                      width: 80,
                      height: 20,
                      child: chip(ringLabel(radii[i], unit)),
                    ),
                  for (var i = 0; i < 4; i++)
                    Marker(
                      point: pointAt(centre, compass, i * 90.0),
                      width: 32,
                      height: 20,
                      child: chip(letter(i * 2)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
