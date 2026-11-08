import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/backup.dart';
import 'package:notoryx_core/data/backup_crypto.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/radio_frames.dart';
import '../support/schema_rollback.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('nx_backup'));
  tearDown(() => temp.delete(recursive: true));

  group('sealing', () {
    test('opens with the right password only', () {
      final sealed = sealBackup(
        [1, 2, 3, 4],
        'correct horse',
        iterations: 1000,
      );
      expect(String.fromCharCodes(sealed.sublist(0, 8)), 'NOTORYXB');
      expect(openBackup(sealed, 'correct horse'), [1, 2, 3, 4]);
      expect(
        () => openBackup(sealed, 'wrong horse'),
        throwsA(isA<BackupException>()),
      );
    });

    test('a changed header or body fails', () {
      final sealed = sealBackup(
        List.filled(64, 7),
        'pw123456',
        iterations: 1000,
      );
      final header = Uint8List.fromList(sealed)..[20] ^= 1;
      final body = Uint8List.fromList(sealed)..[sealed.length - 1] ^= 1;
      expect(
        () => openBackup(header, 'pw123456'),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => openBackup(body, 'pw123456'),
        throwsA(isA<BackupException>()),
      );
    });

    test('other files are refused', () {
      expect(
        () => openBackup(List.filled(100, 0), 'x'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('isn’t a NOTORYX backup'),
          ),
        ),
      );
    });

    test('the same input seals differently each time', () {
      final a = sealBackup([1], 'pw', iterations: 1000);
      final b = sealBackup([1], 'pw', iterations: 1000);
      expect(a, isNot(b));
    });
  });

  group('database', () {
    final self = decodeFrame(selfInfoFrame()) as SelfInfo;

    Future<MeshStore> seed(MeshDatabase db, String text) async {
      final store = MeshStore(db);
      await store.rememberRadio(self);
      final key = self.publicKey.hex;
      await store.saveOutgoing(
        key,
        thread: 'c:1',
        body: text,
        sentAt: 1700000000,
      );
      await store.saveSetting('quick_messages', '["$text"]');
      await store.saveTelemetry(key, key, [1, 116, 1, 0x96]);
      return store;
    }

    test('restore replaces everything with the backup', () async {
      final source = MeshDatabase.inMemory();
      await seed(source, 'from the old phone');
      final payload = await backupPayload(
        source,
        temp: temp,
        appVersion: '0.1.0-test.16',
      );
      await source.close();

      final target = MeshDatabase.inMemory();
      final store = await seed(target, 'on the new phone');
      final read = readPayload(payload, currentSchema: target.schemaVersion);
      expect(read.info.appVersion, '0.1.0-test.16');
      expect(read.info.schemaVersion, target.schemaVersion);

      final watching = store.watchThread(self.publicKey.hex, 'c:1');
      final summary = await restoreDatabase(target, read.sqlite, temp: temp);
      expect(summary, (radios: 1, messages: 1, contacts: 0));

      final messages = await watching.first;
      expect(messages.single.body, 'from the old phone');
      expect(await store.setting('quick_messages'), '["from the old phone"]');
      final key = self.publicKey.hex;
      expect(await store.watchTelemetry(key, key).first, hasLength(1));
      await target.close();
    });

    test('a backup from an older schema is upgraded on restore', () async {
      final file = File('${temp.path}/old.sqlite');
      final old = MeshDatabase(NativeDatabase(file));
      await seed(old, 'from version 6');
      await rollBackTo(old, 6);
      await old.close();
      // A version 6 database, as an old backup would hold.
      final sqlite = await file.readAsBytes();

      final target = MeshDatabase.inMemory();
      await restoreDatabase(target, sqlite, temp: temp);
      final store = MeshStore(target);
      final messages = await store.watchThread(self.publicKey.hex, 'c:1').first;
      expect(messages.single.body, 'from version 6');
      // Tables added after version 6 exist and are empty.
      expect(await store.watchRadioStats(self.publicKey.hex).first, isEmpty);
      await target.close();
    });

    test('a backup from a newer schema is refused', () async {
      final db = MeshDatabase.inMemory();
      final payload = await backupPayload(db, temp: temp, appVersion: 'x');
      await db.close();
      expect(
        () => readPayload(payload, currentSchema: 1),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('a damaged payload is refused', () {
      expect(
        () => readPayload([0, 0, 0, 2, 123, 125, 1, 2, 3], currentSchema: 8),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
