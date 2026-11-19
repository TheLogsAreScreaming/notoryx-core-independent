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
    LatLng view = const LatLng(41.33, -74.2),
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
            initialCenter: view,
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
        // N, E, S, W and at least the outer ring's distance label; inner
        // labels are dropped when the rings are close together.
        expect(find.text('N'), findsOneWidget);
        expect(chips.evaluate().length, inInclusiveRange(5, 8));
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

  testWidgets('just above the bottom card the rings stay small and readable', (
    tester,
  ) async {
    // The view's centre is 2° north of the radio, so the radio sits about
    // 30 px above the 200 px card along the bottom: too little room for
    // the usual fit.
    await pumpRings(
      tester,
      rotation: 0,
      zoom: 6,
      view: const LatLng(43.33, -73.09),
    );
    final radioAt =
        tester.getCenter(find.byType(FlutterMap)) + const Offset(0, 120);
    final chips = find.descendant(
      of: find.byType(RangeRingsLayer),
      matching: find.byType(Text),
    );
    final rects = [
      for (final chip in chips.evaluate())
        tester.getRect(find.byWidget(chip.widget)),
    ];
    // The compass letters sit close around the radio, not out at the size
    // of the whole view.
    for (final letter in ['N', 'E', 'S', 'W']) {
      final at = tester.getCenter(find.text(letter));
      expect((at - radioAt).distance, lessThan(90), reason: letter);
    }
    // No two labels overlap.
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: '${rects[i]} overlaps ${rects[j]}',
        );
      }
    }
  });
}
