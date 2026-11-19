import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/range_rings.dart';
import '../l10n/l10n.dart';

/// Four distance rings around [centre], sized to the visible map, with a
/// label on each ring's north point, faint spokes every 45° and the
/// compass letters just outside the outer ring. Ignores taps, so markers
/// underneath still work.
class RangeRingsLayer extends StatelessWidget {
  const RangeRingsLayer({required this.centre, required this.unit, super.key});

  final LatLng centre;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final view = camera.visibleBounds;
    final radii = ringRadii(
      viewReach(
        camera.center,
        north: view.north,
        south: view.south,
        east: view.east,
        west: view.west,
      ),
      unit,
    );
    final outer = radii.last;
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
                  for (final r in radii)
                    Marker(
                      point: pointAt(centre, r, 0),
                      width: 80,
                      height: 20,
                      child: chip(ringLabel(r, unit)),
                    ),
                  for (var i = 0; i < 4; i++)
                    Marker(
                      point: pointAt(centre, outer * 1.12, i * 90.0),
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
