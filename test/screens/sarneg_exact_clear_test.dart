// The SARNEG options show whether copied text is cleared on the minute, and
// open Android's alarm settings when it isn't allowed.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/l10n/l10n.dart';
import 'package:notoryx_core/screens/sarneg/sarneg.dart';
import 'package:notoryx_core/screens/sarneg/sarneg_ui.dart';
import 'package:notoryx_core/screens/sarneg/secret_clipboard.dart';

const _channel = MethodChannel('notoryx/clipboard');

Widget _app() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: const SarnegScreen(),
);

void main() {
  final calls = <String>[];
  var status = 'notAllowed';

  setUp(() {
    calls.clear();
    status = 'notAllowed';
    debugActAsAndroid = true;
    SarnegKeys.instance = SarnegKeys(
      storage: MemorySarnegStorage(
        jsonEncode(SarnegKeySet(word: 'BLACKHORSE').toJson()),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          return call.method == 'exactClearStatus' ? status : null;
        });
  });

  tearDown(() {
    debugActAsAndroid = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
  }

  testWidgets('not allowed: says so and opens the alarm settings', (
    tester,
  ) async {
    await open(tester);
    final tile = find.byKey(const ValueKey('sarneg-exact-clear'));
    await tester.ensureVisible(tile);
    expect(find.textContaining('may clear it up to a minute late'), findsOne);
    await tester.tap(tile);
    await tester.pump();
    expect(calls, contains('openExactClearSettings'));
  });

  testWidgets('allowed: says it is on, nothing to tap', (tester) async {
    status = 'allowed';
    await open(tester);
    expect(
      find.text('On. Copied SARNEG text is cleared after one minute.'),
      findsOne,
    );
    await tester.tap(find.byKey(const ValueKey('sarneg-exact-clear')));
    await tester.pump();
    expect(calls, isNot(contains('openExactClearSettings')));
  });

  testWidgets('hidden where it does not apply', (tester) async {
    status = 'notNeeded';
    await open(tester);
    expect(find.byKey(const ValueKey('sarneg-exact-clear')), findsNothing);
    debugActAsAndroid = false;
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(find.byKey(const ValueKey('sarneg-exact-clear')), findsNothing);
  });
}
