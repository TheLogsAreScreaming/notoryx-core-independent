/// Grouping map pins that would overlap at the current zoom into one
/// numbered circle.
library;

import 'dart:ui' show Offset;

import 'package:latlong2/latlong.dart';

/// Pins closer than this on screen, in logical pixels, share a cluster.
const clusterRadius = 56.0;

/// From this zoom in, every pin is drawn on its own.
const clusterUntilZoom = 15.0;

/// One or more items drawn as a single pin at [at].
typedef MapCluster<T> = ({LatLng at, List<T> items});

/// Groups [items] whose screen positions (from [project]) are within
/// [radius] of a cluster's first item. Single items come back as clusters
/// of one, placed exactly on their own position; bigger clusters sit at the
/// average of their members. Order follows [items].
List<MapCluster<T>> clusterPins<T>(
  List<T> items, {
  required LatLng Function(T item) position,
  required Offset Function(LatLng at) project,
  double radius = clusterRadius,
}) {
  final anchors = <Offset>[];
  final groups = <List<T>>[];
  for (final item in items) {
    final p = project(position(item));
    var placed = false;
    for (var i = 0; i < anchors.length; i++) {
      if ((anchors[i] - p).distance <= radius) {
        groups[i].add(item);
        placed = true;
        break;
      }
    }
    if (!placed) {
      anchors.add(p);
      groups.add([item]);
    }
  }
  return [
    for (final g in groups)
      (
        at: g.length == 1
            ? position(g.single)
            : LatLng(
                g.map((i) => position(i).latitude).reduce((a, b) => a + b) /
                    g.length,
                g.map((i) => position(i).longitude).reduce((a, b) => a + b) /
                    g.length,
              ),
        items: g,
      ),
  ];
}
