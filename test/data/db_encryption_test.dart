import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/backup.dart';
import 'package:notoryx_core/data/data.dart';

final class _Keys implements DbKeyStore {
  String? value;
  bool broken = false;

  @override
  Future<String?> read() async {
    if (broken) throw StateError('no storage');
    return value;
  }

  @override
  Future<void> write(String key) async {
    if (broken) throw StateError('no storage');
    value = key;
  }

  @override
  Future<void> delete() async => value = null;
}

void main() {
  late Directory dir;
  late File file;
  late _Keys keys;

  MeshDatabase open(String? key) => MeshDatabase(
    NativeDatabase(
      file,
      setup: key == null ? null : (raw) => raw.execute("PRAGMA key = '$key'"),
    ),
  );

  Future<String?> saved(MeshDatabase db) => MeshStore(db).setting('marker');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nx_enc');
    file = File('${dir.path}/notoryx.sqlite');
    keys = _Keys();
    final db = open(null);
    await MeshStore(db).saveSetting('marker', 'kept');
    await db.close();
  });

  tearDown(() => dir.delete(recursive: true));

  test('encrypts in place, keeps data, and needs the key', () async {
    expect(isPlainDatabase(file), isTrue);
    final db = open(null);
    await encryptDatabase(db, file, keys);
    expect(await saved(db), 'kept', reason: 'still works while open');
    await db.close();

    expect(isPlainDatabase(file), isFalse);
    expect(dbSafetyCopy(file).existsSync(), isFalse);
    final key = await prepareDatabase(file, keys);
    expect(key, isNotNull);

    final reopened = open(key);
    expect(await saved(reopened), 'kept');
    await reopened.close();

    final noKey = open(null);
    await expectLater(saved(noKey), throwsA(anything));
    await noKey.close();
  });

  test('turns back off with data intact', () async {
    var db = open(null);
    await encryptDatabase(db, file, keys);
    await decryptDatabase(db, file, keys);
    await db.close();
    expect(isPlainDatabase(file), isTrue);
    expect(keys.value, isNull);
    db = open(null);
    expect(await saved(db), 'kept');
    await db.close();
  });

  test('broken secure storage changes nothing', () async {
    keys.broken = true;
    final db = open(null);
    await expectLater(
      encryptDatabase(db, file, keys),
      throwsA(isA<DbEncryptionException>()),
    );
    await db.close();
    expect(isPlainDatabase(file), isTrue);
  });

  test('a read failure at launch leaves the file alone', () async {
    final db = open(null);
    await encryptDatabase(db, file, keys);
    await db.close();
    keys.broken = true;
    await expectLater(prepareDatabase(file, keys), throwsA(anything));
    expect(file.existsSync(), isTrue);
  });

  test('a lost key sets the file aside, never deletes it', () async {
    final db = open(null);
    await encryptDatabase(db, file, keys);
    await db.close();
    keys.value = null;
    File? aside;
    final key = await prepareDatabase(
      file,
      keys,
      onUnreadable: (f) => aside = f,
    );
    expect(key, isNull);
    expect(file.existsSync(), isFalse);
    expect(aside!.existsSync(), isTrue);
  });

  test('an interrupted conversion goes back to the safety copy', () async {
    await file.copy(dbSafetyCopy(file).path);
    await file.writeAsBytes(List.filled(4096, 7));
    expect(await prepareDatabase(file, keys), isNull);
    expect(dbSafetyCopy(file).existsSync(), isFalse);
    final db = open(null);
    expect(await saved(db), 'kept');
    await db.close();
  });

  test('a leftover key with a plain file is cleared', () async {
    keys.value = 'stale';
    expect(await prepareDatabase(file, keys), isNull);
    expect(keys.value, isNull);
  });

  test('a backup from an encrypted phone restores on a plain one', () async {
    final db = open(null);
    await encryptDatabase(db, file, keys);
    final payload = await backupPayload(
      db,
      temp: dir,
      appVersion: 'test',
      key: keys.value,
    );
    await db.close();

    final other = MeshDatabase.inMemory();
    final read = readPayload(payload, currentSchema: other.schemaVersion);
    await restoreDatabase(other, read.sqlite, temp: dir);
    expect(await saved(other), 'kept');
    await other.close();
  });

  test('a plain backup restores into an encrypted database', () async {
    final source = MeshDatabase.inMemory();
    await MeshStore(source).saveSetting('marker', 'from backup');
    final payload = await backupPayload(source, temp: dir, appVersion: 'test');
    await source.close();

    final db = open(null);
    await encryptDatabase(db, file, keys);
    final read = readPayload(payload, currentSchema: db.schemaVersion);
    await restoreDatabase(db, read.sqlite, temp: dir);
    expect(await saved(db), 'from backup');
    await db.close();
  });
}
