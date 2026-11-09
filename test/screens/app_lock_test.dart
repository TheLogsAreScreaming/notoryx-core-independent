import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/app_lock.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/screens/app_lock_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MeshDatabase db;
  late List<AuthResult> answers;
  late DateTime now;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, {String? saved}) async {
    db = MeshDatabase.inMemory();
    now = DateTime(2026, 11, 9, 9);
    if (saved != null) {
      await tester.runAsync(
        () => MeshStore(db).saveSetting(appLockSetting, saved),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appAuthenticatorProvider.overrideWithValue(
            () async => answers.removeAt(0),
          ),
          appLockClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          builder: (_, child) => AppLockGate(child: child!),
          home: const AppLockSettingsScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(db.close);
  }

  void lifecycle(WidgetTester tester, AppLifecycleState s) =>
      tester.binding.handleAppLifecycleStateChanged(s);

  const on = '{"enabled":true,"seconds":60}';

  testWidgets('locked at launch; a good unlock opens it', (tester) async {
    answers = [AuthResult.failed, AuthResult.success];
    await open(tester, saved: on);
    expect(find.text('NOTORYX Core is locked'), findsOneWidget);
    expect(find.textContaining('didn’t unlock'), findsOneWidget);
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(find.text('NOTORYX Core is locked'), findsNothing);
    await close(tester);
  });

  testWidgets('a phone with no lock set does not shut you out', (tester) async {
    answers = [AuthResult.unavailable];
    await open(tester, saved: on);
    expect(find.text('NOTORYX Core is locked'), findsNothing);
    await close(tester);
  });

  testWidgets('relocks only after being away long enough', (tester) async {
    answers = [AuthResult.success, AuthResult.failed];
    await open(tester, saved: on);

    lifecycle(tester, AppLifecycleState.hidden);
    now = now.add(const Duration(seconds: 30));
    lifecycle(tester, AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text('NOTORYX Core is locked'), findsNothing);

    lifecycle(tester, AppLifecycleState.hidden);
    now = now.add(const Duration(minutes: 2));
    lifecycle(tester, AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text('NOTORYX Core is locked'), findsOneWidget);
    await close(tester);
  });

  testWidgets('turning it on needs the phone, and a lock set', (tester) async {
    answers = [AuthResult.unavailable, AuthResult.success];
    await open(tester);
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(
      find.text('Set a screen lock on this device first.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(
      await tester.runAsync(() => MeshStore(db).setting(appLockSetting)),
      contains('"enabled":true'),
    );
    await close(tester);
  });

  testWidgets('a bad or missing setting leaves it off', (tester) async {
    expect(parseAppLock(null).enabled, isFalse);
    expect(parseAppLock('junk').enabled, isFalse);
    expect(parseAppLock(on).timeout, const Duration(minutes: 1));
  });
}
