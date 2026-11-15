import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/app_background.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/screens/appearance_screen.dart';
import 'package:notoryx_core/screens/background_layer.dart';

class _Fixed extends AppBackgroundNotifier {
  _Fixed(this.value);

  final AppBackground value;

  @override
  AppBackground build() => value;

  @override
  Future<void> set(AppBackground value) async => state = value;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> show(
    WidgetTester tester,
    AppBackground bg, {
    bool powerSave = false,
    bool reduceMotion = false,
  }) async {
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appBackgroundProvider.overrideWith(() => _Fixed(bg)),
          powerSaveProvider.overrideWith((ref) async => powerSave),
        ],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const MaterialApp(
            home: BackgroundLayer(
              child: Scaffold(
                body: GlassCard(child: ListTile(title: Text('Alice'))),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the theme background changes nothing', (tester) async {
    await show(tester, const AppBackground());
    expect(find.byType(BackgroundPaint), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('a custom background puts lists on frosted glass', (
    tester,
  ) async {
    await show(tester, const AppBackground(kind: BackgroundKind.gradient));
    expect(find.byType(BackgroundPaint), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final scaffold = Theme.of(tester.element(find.byType(Scaffold)));
    expect(scaffold.scaffoldBackgroundColor, Colors.transparent);
  });

  testWidgets('reduce motion turns the blur off', (tester) async {
    await show(
      tester,
      const AppBackground(kind: BackgroundKind.solid),
      reduceMotion: true,
    );
    expect(find.byType(BackgroundPaint), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('battery saver turns the blur off', (tester) async {
    await show(
      tester,
      const AppBackground(kind: BackgroundKind.mesh),
      powerSave: true,
    );
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('Appearance offers the backgrounds and saves a pick', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appBackgroundProvider.overrideWith(() => _Fixed(const AppBackground())),
        powerSaveProvider.overrideWith((ref) async => false),
        backgroundPhotoPickerProvider.overrideWithValue(
          () async => Uint8List(0),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppearanceScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Theme default'), findsOneWidget);
    expect(find.text('Dim'), findsNothing);

    await tester.tap(find.text('Mesh gradient'));
    await tester.pump();
    expect(container.read(appBackgroundProvider).kind, BackgroundKind.mesh);
    expect(find.text('Second colour'), findsOneWidget);
    expect(find.text('Dim'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Purple').first);
    await tester.pump();
    expect(container.read(appBackgroundProvider).first, backgroundColours[8]);

    await tester.tap(find.text('Your photo'));
    await tester.pump();
    expect(find.textContaining('isn’t a picture'), findsOneWidget);
    expect(container.read(appBackgroundProvider).kind, BackgroundKind.mesh);
  });
}
