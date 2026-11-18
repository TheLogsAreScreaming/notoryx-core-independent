import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/map_clusters.dart';

void main() {
  // One degree is 100 screen pixels, to keep the sums easy.
  Offset project(LatLng at) => Offset(at.longitude * 100, -at.latitude * 100);
  LatLng position(LatLng p) => p;

  test('pins close together on screen share one cluster', () {
    final clusters = clusterPins(
      const [LatLng(0, 0), LatLng(0.2, 0.2), LatLng(5, 5)],
      position: position,
      project: project,
    );
    expect(clusters, hasLength(2));
    expect(clusters.first.items, hasLength(2));
    expect(clusters.first.at, const LatLng(0.1, 0.1));
    expect(clusters.last.items.single, const LatLng(5, 5));
    expect(clusters.last.at, const LatLng(5, 5));
  });

  test('a negative radius keeps every pin apart, even on the same spot', () {
    final clusters = clusterPins(
      const [LatLng(1, 1), LatLng(1, 1)],
      position: position,
      project: project,
      radius: -1,
    );
    expect(clusters.map((c) => c.items.length), [1, 1]);
  });

  test('nothing in, nothing out', () {
    expect(
      clusterPins(const <LatLng>[], position: position, project: project),
      isEmpty,
    );
  });
}
