import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/path_graph.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/route_screen.dart';

Contact node(
  String name,
  String key, {
  NodeType type = NodeType.repeater,
  int pathLength = pathUnknown,
  List<int> path = const [],
}) => Contact(
  radioKey: 'r',
  publicKey: key.padRight(64, '0'),
  name: name,
  type: type.value,
  flags: 0,
  outPathLength: pathLength,
  outPath: Uint8List.fromList([...path, ...List.filled(64 - path.length, 0)]),
  lastAdvert: 0,
  lastModified: 0,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final hill = node(
    'Hill',
    '42',
    type: NodeType.chat,
    pathLength: 2,
    path: [0x11, 0x22],
  );
  final contacts = [
    hill,
    node('Tower', '11'),
    node('Barn', '22'),
    node('Mast', '33'),
  ];

  Future<void> open(WidgetTester tester) async {
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          contactsProvider.overrideWith((ref, _) => Stream.value(contacts)),
          heardPathsProvider.overrideWith(
            (ref, _) => Stream.value([
              HeardPathRow(
                id: 1,
                radioKey: 'r',
                hops: '22>33',
                hashBytes: 1,
                count: 8,
                lastSnr: 6,
                lastAt: 0,
              ),
            ]),
          ),
        ],
        child: MaterialApp(home: RouteScreen(contact: hill)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each link is charted with words, not just colour', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(find.text('Route to Hill'), findsOneWidget);
    expect(find.text('Tower'), findsOneWidget);
    expect(find.text('Barn'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('Link from You to Tower: Not measured, out –, back –'),
      ),
      findsOneWidget,
    );
    expect(find.text('Connect to the radio first.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a better heard route is suggested; own routes can be built', (
    tester,
  ) async {
    await open(tester);
    await tester.scrollUntilVisible(find.text('Mast → Barn'), 200);
    expect(
      find.textContaining('Suggested: more reliable than the route in use'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Flood the mesh'), 200);
    expect(find.text('Flood the mesh'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Build your own route'), 200);
    await tester.tap(find.text('Build your own route'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add hop'), 200);
    await tester.tap(find.text('Add hop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mast').last);
    await tester.pumpAndSettle();
    expect(find.text('1. Mast'), findsOneWidget);
    expect(find.byTooltip('Remove Mast'), findsOneWidget);
  });
}
