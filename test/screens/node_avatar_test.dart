import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/node_look.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/node_avatar.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> cleanUp(WidgetTester tester, MeshDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Future<String?> stored(WidgetTester tester, MeshDatabase db) => tester
      .runAsync<String?>(() => MeshStore(db).setting(nodeLookKey('aa11')));

  Future<MeshDatabase> open(
    WidgetTester tester, {
    Future<Uint8List?> Function()? picker,
  }) async {
    final db = MeshDatabase.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (picker != null) nodePhotoPickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Column(
                children: [
                  const NodeAvatar(
                    publicKey: 'AA11',
                    name: 'Alice Smith',
                    type: NodeType.chat,
                  ),
                  TextButton(
                    onPressed: () => showNodeLookPicker(
                      context,
                      ref,
                      publicKey: 'AA11',
                      name: 'Alice Smith',
                      type: NodeType.chat,
                    ),
                    child: const Text('pick'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return db;
  }

  CircleAvatar avatar(WidgetTester tester) =>
      tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);

  testWidgets('shows the type icon until a look is picked', (tester) async {
    final db = await open(tester);
    expect(find.byIcon(Icons.person_outline), findsWidgets);
    expect(find.text('AS'), findsNothing);
    await cleanUp(tester, db);
  });

  testWidgets('picking a colour shows initials on it, Clear removes it', (
    tester,
  ) async {
    final db = await open(tester);
    await tester.tap(find.text('pick'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Blue'));
    await settle(tester);
    expect(find.text('AS'), findsOneWidget);
    expect(avatar(tester).backgroundColor, nodeColours[6]);
    expect(await stored(tester, db), isNotNull);

    await tester.tap(find.text('pick'));
    await settle(tester);
    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(find.text('AS'), findsNothing);
    expect(await stored(tester, db), isNull);
    await cleanUp(tester, db);
  });

  testWidgets('a picked photo becomes the avatar', (tester) async {
    final jpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 8, height: 8)),
    );
    final db = await open(tester, picker: () async => jpeg);
    await tester.tap(find.text('pick'));
    await settle(tester);
    await tester.tap(find.text('Choose photo'));
    await settle(tester);
    expect(avatar(tester).backgroundImage, isA<MemoryImage>());
    await cleanUp(tester, db);
  });

  testWidgets('a file that isn’t a picture is refused', (tester) async {
    final db = await open(tester, picker: () async => Uint8List(0));
    await tester.tap(find.text('pick'));
    await settle(tester);
    await tester.tap(find.text('Choose photo'));
    await settle(tester);
    expect(find.textContaining('isn’t a picture'), findsOneWidget);
    await cleanUp(tester, db);
  });
}
