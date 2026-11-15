import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/terrain_profile.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/screens/terrain_profile_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> open(
    WidgetTester tester,
    Future<List<double>?> Function(List<LatLng>) lookup,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          elevationLookupProvider.overrideWithValue(lookup),
        ],
        child: const MaterialApp(
          home: TerrainProfileScreen(
            from: LatLng(40, -74),
            to: LatLng(40.05, -74),
            name: 'Hill',
          ),
        ),
      ),
    );
  }

  testWidgets('shows the chart, legend and a verdict after checking', (
    tester,
  ) async {
    await open(tester, (points) async => List.filled(points.length, 0));
    expect(find.text('Terrain to Hill'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.text('Check terrain'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileLegend), findsOneWidget);
    expect(find.text('Fresnel zone'), findsOneWidget);
    expect(find.byType(FresnelVerdictRow), findsOneWidget);
    expect(find.textContaining('Fresnel zone'), findsWidgets);
  });

  testWidgets('says so when heights can’t be fetched', (tester) async {
    await open(tester, (_) async => null);
    await tester.tap(find.text('Check terrain'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn’t get ground heights'), findsOneWidget);
    expect(find.byType(ProfileLegend), findsNothing);
  });
}
