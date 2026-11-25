// With no radio connected, Radio settings still opens the screens that are
// kept on this device, such as SARNEG and Appearance.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/l10n/l10n.dart';
import 'package:notoryx_core/screens/radio_settings_screen.dart';
import 'package:notoryx_core/screens/sarneg/sarneg_ui.dart';

import '../support/fake_notifier.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() {
    SarnegKeys.instance = SarnegKeys(storage: MemorySarnegStorage());
  });

  testWidgets('without a radio, settings kept on the device still open', (
    tester,
  ) async {
    final db = MeshDatabase.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          messageNotifierProvider.overrideWithValue(FakeNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const RadioSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Connect to the radio to change its settings.'),
      findsOneWidget,
    );
    // The radio's own settings wait for a connection.
    expect(find.text('Transmit power'), findsNothing);
    expect(find.text('Reboot radio'), findsNothing);
    expect(find.byKey(const ValueKey('offline-appearance')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('offline-sarneg')));
    await tester.pumpAndSettle();
    expect(find.text('No code word on this phone yet.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
