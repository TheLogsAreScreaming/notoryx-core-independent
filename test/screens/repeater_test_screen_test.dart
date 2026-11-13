import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/repeater_test.dart';
import 'package:notoryx_core/app/wardrive.dart';
import 'package:notoryx_core/data/data.dart' hide WardriveHit;
import 'package:notoryx_core/screens/repeater_test_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> open(WidgetTester tester, RepeaterProbe? probe) async {
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repeaterProbeProvider.overrideWith((ref) => probe),
          contactsProvider.overrideWith((ref, _) => Stream.value(const [])),
          discoveredProvider.overrideWith((ref, _) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: RepeaterTestScreen()),
      ),
    );
  }

  testWidgets('opening it runs a test and lists who answered', (tester) async {
    final semantics = tester.ensureSemantics();
    final answers = Completer<List<WardriveHit>>();
    await open(tester, () => answers.future);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Listening for answers'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'one test at a time',
    );

    answers.complete([
      (
        publicKey: 'ab12cd34'.padRight(64, '0'),
        heardUs: 5.25,
        weHeard: -3.5,
        rssi: -97,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('1 repeater answered'), findsOneWidget);
    expect(find.text('Unknown repeater'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Unknown repeater, Usable signal. It heard you at 5.3 dB, '
        'you heard it at -3.5 dB, signal strength -97 dBm.',
      ),
      findsOneWidget,
    );
    expect(find.text('Test again'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('no answers explains why', (tester) async {
    await open(tester, () async => const []);
    await tester.pumpAndSettle();
    expect(find.text('No repeaters answered'), findsOneWidget);
  });

  testWidgets('without a radio it asks to connect', (tester) async {
    await open(tester, null);
    await tester.pumpAndSettle();
    expect(find.text('Connect to the radio first.'), findsOneWidget);
  });
}
