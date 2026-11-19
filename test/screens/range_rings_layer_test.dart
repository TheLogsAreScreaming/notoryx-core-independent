import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/range_rings.dart';
import 'package:notoryx_core/l10n/generated/app_localizations.dart';
import 'package:notoryx_core/screens/range_rings_layer.dart';

void main() {
  const covered = EdgeInsets.fromLTRB(8, 8, 84, 200);
  const radio = LatLng(41.33, -73.09);

  Future<Rect> pumpRings(
    WidgetTester tester, {
    required double rotation,
    required double zoom,
  }) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FlutterMap(
          options: MapOptions(
            // The radio sits right of centre, nearer the toolbar.
            initialCenter: const LatLng(41.33, -74.2),
            initialZoom: zoom,
            initialRotation: rotation,
          ),
          children: const [
            RangeRingsLayer(
              centre: radio,
              unit: DistanceUnit.imperial,
              covered: covered,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    return covered.deflateRect(tester.getRect(find.byType(FlutterMap)));
  }

  for (final rotation in [0.0, 8.0, -30.0]) {
    testWidgets('labels and letters stay clear at $rotation° rotation', (
      tester,
    ) async {
      for (final zoom in [5.5, 6.0, 6.3, 6.7]) {
        final clear = await pumpRings(tester, rotation: rotation, zoom: zoom);
        final chips = find.descendant(
          of: find.byType(RangeRingsLayer),
          matching: find.byType(Text),
        );
        // 4 distance labels and N, E, S, W.
        expect(chips, findsNWidgets(8));
        for (final chip in chips.evaluate()) {
          final rect = tester.getRect(find.byWidget(chip.widget));
          expect(
            clear.contains(rect.topLeft) && clear.contains(rect.bottomRight),
            isTrue,
            reason: 'zoom $zoom: $rect is outside the clear part, $clear',
          );
        }
      }
    });
  }
}
