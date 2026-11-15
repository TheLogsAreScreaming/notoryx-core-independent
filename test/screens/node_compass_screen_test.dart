import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/compass.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/position.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/screens/node_compass_screen.dart';

class FakeCompass implements CompassSource {
  FakeCompass({required this.has});

  final bool has;
  final controller = StreamController<HeadingReading>.broadcast();

  @override
  Future<bool> available() async => has;

  @override
  Stream<HeadingReading> headings() => controller.stream;

  @override
  Future<double?> declination(LatLng at) async => 0;
}

/// Sends a reading and lets the screen rebuild.
Future<void> send(
  WidgetTester tester,
  FakeCompass compass,
  double heading,
  int accuracy,
) async {
  compass.controller.add((heading: heading, accuracy: accuracy));
  await tester.pump();
  await tester.pump();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> open(
    WidgetTester tester,
    CompassSource compass, {
    LatLng? phone,
    LatLng? askedPhone,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          compassSourceProvider.overrideWithValue(compass),
          allowedPhonePositionProvider.overrideWithValue(() async => phone),
          phonePositionProvider.overrideWithValue(() async => askedPhone),
        ],
        child: const MaterialApp(
          home: NodeCompassScreen(name: 'Hill', target: LatLng(40.01, -74)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('points at the node and says which way to turn', (tester) async {
    final compass = FakeCompass(has: true);
    await open(tester, compass, phone: const LatLng(40, -74));
    expect(find.text('Bearing 0° N'), findsOneWidget);
    expect(find.text('From the phone’s location'), findsOneWidget);
    expect(find.text('Use phone location'), findsNothing);

    await send(tester, compass, 90, 3);
    expect(find.text('Turn left 90°'), findsOneWidget);

    for (var i = 0; i < 40; i++) {
      await send(tester, compass, 2, 3);
    }
    expect(find.text('On target'), findsOneWidget);

    await send(tester, compass, 2, 1);
    expect(find.textContaining('figure of eight'), findsOneWidget);
  });

  testWidgets('without a compass the arrow is north-up with a note', (
    tester,
  ) async {
    await open(tester, FakeCompass(has: false), phone: const LatLng(40, -74));
    expect(find.textContaining('No compass'), findsOneWidget);
    expect(find.textContaining('Turn'), findsNothing);
    expect(find.text('Bearing 0° N'), findsOneWidget);
  });

  testWidgets('without a position it offers the phone location', (
    tester,
  ) async {
    await open(
      tester,
      FakeCompass(has: false),
      askedPhone: const LatLng(40.02, -74),
    );
    expect(find.textContaining('No position'), findsWidgets);
    await tester.tap(find.text('Use phone location'));
    await tester.pumpAndSettle();
    expect(find.text('Bearing 180° S'), findsOneWidget);
    expect(find.text('Use phone location'), findsNothing);
  });
}
