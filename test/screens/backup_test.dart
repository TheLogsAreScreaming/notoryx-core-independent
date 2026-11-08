import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:notoryx_core/app/about.dart';
import 'package:notoryx_core/app/backup_service.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_notifier.dart';
import '../support/fake_radio_link.dart';
import '../support/scripted_radio.dart';

class _Connector implements RadioConnector {
  _Connector(this.newLink);

  final FakeRadioLink Function() newLink;

  @override
  bool get supportsUsb => false;

  @override
  Stream<BleTarget> scanBluetooth({bool all = false}) => Stream.value(
    const BleTarget(deviceId: 'aa', label: 'MeshCore-Base', rssi: -60),
  );

  @override
  Future<List<UsbTarget>> listUsb() async => const [];

  @override
  Future<RadioLink> open(RadioTarget target) async => newLink();
}

class _Files implements BackupFiles {
  Uint8List? saved;
  String? name;

  @override
  Future<bool> save(String name, Uint8List bytes) async {
    this.name = name;
    saved = bytes;
    return true;
  }

  @override
  Future<Uint8List?> pick() async => saved;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;
  late _Files files;
  late Directory temp;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<String?> quick(WidgetTester tester) => tester
      .runAsync(() => MeshStore(db).setting('quick_messages'))
      .then((v) => v);

  testWidgets('back up, change something, restore it', (tester) async {
    db = MeshDatabase.inMemory();
    files = _Files();
    temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nx_backup_ui'),
    ))!;
    await tester.runAsync(
      () => MeshStore(db).saveSetting('quick_messages', '["Backed up"]'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          radioConnectorProvider.overrideWithValue(
            _Connector(() {
              final link = FakeRadioLink();
              ScriptedRadio(link);
              return link;
            }),
          ),
          messageNotifierProvider.overrideWithValue(FakeNotifier()),
          foregroundCheckProvider.overrideWithValue(() => true),
          appVersionProvider.overrideWith(
            (ref) async => (
              name: 'NOTORYX Independent',
              version: '0.1.0-test.16',
              build: '16',
            ),
          ),
          backupFilesProvider.overrideWithValue(files),
          backupTempProvider.overrideWith((ref) async => temp),
          backupIterationsProvider.overrideWithValue(1000),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('About'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Backup and restore'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.tap(find.text('Backup and restore'));
    await settle(tester);

    // A short or mismatched password can't be used.
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'short');
    await tester.enterText(
      find.widgetWithText(TextField, 'Password again'),
      'short',
    );
    await tester.pump();
    expect(find.text('At least 8 characters.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'trail mix 42',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password again'),
      'trail mix 4',
    );
    await tester.pump();
    expect(find.text('The two passwords don’t match.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password again'),
      'trail mix 42',
    );
    await tester.pump();

    await tester.tap(find.text('Save backup file'));
    await settle(tester);
    expect(files.saved, isNotNull);
    expect(
      files.name,
      matches(RegExp(r'^NOTORYX-backup-\d{4}-\d\d-\d\d\.notoryx$')),
    );
    expect(String.fromCharCodes(files.saved!.sublist(0, 8)), 'NOTORYXB');

    await tester.runAsync(
      () => MeshStore(db).saveSetting('quick_messages', '["Changed"]'),
    );

    // Wrong password first (once the "saved" snackbar has gone).
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await tester.tap(find.text('Choose backup file'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password').last,
      'nope nope',
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(
      find.text('Wrong password, or the file has been changed.'),
      findsOneWidget,
    );
    expect(await quick(tester), '["Changed"]');

    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await tester.tap(find.text('Choose backup file'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password').last,
      'trail mix 42',
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(find.text('Replace everything on this device?'), findsOneWidget);
    expect(find.textContaining('(app 0.1.0-test.16)'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await settle(tester);
    expect(
      find.textContaining('Restored 0 messages from 0 radios.'),
      findsOneWidget,
    );
    expect(await quick(tester), '["Backed up"]');

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(() async {
      await db.close().timeout(const Duration(seconds: 2), onTimeout: () {});
      await temp.delete(recursive: true);
    });
  });
}
