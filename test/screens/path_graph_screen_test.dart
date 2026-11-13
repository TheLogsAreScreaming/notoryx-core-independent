import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/path_graph.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/l10n/generated/app_localizations.dart';
import 'package:notoryx_core/screens/path_graph_screen.dart';

HeardPathRow path(String hops, int count) => HeardPathRow(
  id: 0,
  radioKey: 'r',
  hops: hops,
  hashBytes: 1,
  count: count,
  lastSnr: null,
  lastAt: 0,
);

void main() {
  testWidgets('the path graph switches between the list and the network', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          radioKeyProvider.overrideWithValue('r'),
          heardPathsProvider.overrideWith(
            (ref, key) => Stream.value([path('a1>b2', 3), path('b2', 2)]),
          ),
          contactsProvider.overrideWith((ref, key) => Stream.value(const [])),
          discoveredProvider.overrideWith((ref, key) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PathGraphScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('B2'), findsOneWidget); // the list
    await tester.tap(find.text('Network'));
    await tester.pump();
    expect(find.byKey(const Key('path-network')), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.tapAt(tester.getCenter(find.byKey(const Key('path-network'))));
    await tester.pump();
    await tester.tap(find.text('List'));
    await tester.pump();
    expect(find.byKey(const Key('path-network')), findsNothing);
    expect(find.byType(ExpansionTile), findsOneWidget);
  });
}
