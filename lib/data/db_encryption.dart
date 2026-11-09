/// Encrypting the on-device database, and getting back safely if that is
/// interrupted.
///
/// The key is random and lives in the platform's secure storage, never in
/// the database. Whether a file is encrypted is read from its header.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database.dart';

/// Where the database key is kept.
abstract interface class DbKeyStore {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> delete();
}

final class SecureDbKeyStore implements DbKeyStore {
  const SecureDbKeyStore();

  static const _storage = FlutterSecureStorage();
  static const _name = 'notoryx_db_key';

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String key) => _storage.write(key: _name, value: key);

  @override
  Future<void> delete() => _storage.delete(key: _name);
}

/// Why encryption couldn't be changed. Nothing has been altered.
final class DbEncryptionException implements Exception {
  const DbEncryptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _plainHeader = 'SQLite format 3';

/// Whether [file] is not encrypted. A file that doesn't exist yet counts.
bool isPlainDatabase(File file) {
  if (!file.existsSync() || file.lengthSync() == 0) return true;
  final raf = file.openSync();
  try {
    return String.fromCharCodes(raf.readSync(_plainHeader.length)) ==
        _plainHeader;
  } finally {
    raf.closeSync();
  }
}

/// A new random key, as hex.
String generateDbKey([Random? random]) {
  final rng = random ?? Random.secure();
  return [
    for (var i = 0; i < 32; i++)
      rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// The safety copy kept only while a conversion runs.
File dbSafetyCopy(File file) => File('${file.path}.converting');

/// The key to open [file] with, after repairing anything an interrupted
/// conversion left. Null means open it without a key.
///
/// An encrypted file whose key is gone can never be read. It is set aside,
/// not deleted, and [onUnreadable] is called so a fresh database can open.
/// If secure storage fails, this throws and leaves the file alone.
Future<String?> prepareDatabase(
  File file,
  DbKeyStore store, {
  void Function(File setAside)? onUnreadable,
  DateTime Function() clock = DateTime.now,
}) async {
  final safety = dbSafetyCopy(file);
  // It only outlives a conversion that didn't finish.
  if (safety.existsSync()) await safety.rename(file.path);
  final key = await store.read();
  if (isPlainDatabase(file)) {
    if (key != null) await store.delete();
    return null;
  }
  if (key != null) return key;
  final aside = await file.rename(
    '${file.path}.unreadable-${clock().millisecondsSinceEpoch}',
  );
  onUnreadable?.call(aside);
  return null;
}

Future<void> _withSafetyCopy(
  MeshDatabase db,
  File file,
  Future<void> Function() change,
) async {
  final safety = dbSafetyCopy(file);
  if (safety.existsSync()) await safety.delete();
  await db.customStatement('VACUUM INTO ?', [safety.path]);
  await change();
  await db.customSelect('SELECT COUNT(*) FROM sqlite_master').get();
  await safety.delete();
}

/// Encrypts the open database [db], stored at [file], in place.
Future<void> encryptDatabase(
  MeshDatabase db,
  File file,
  DbKeyStore store,
) async {
  final key = generateDbKey();
  try {
    await store.write(key);
    if (await store.read() != key) throw StateError('key did not read back');
  } on Object {
    throw const DbEncryptionException(
      'This device’s secure storage isn’t available, so nothing changed.',
    );
  }
  await _withSafetyCopy(
    db,
    file,
    () => db.customStatement("PRAGMA rekey = '$key'"),
  );
  if (isPlainDatabase(file)) {
    await store.delete();
    throw const DbEncryptionException('Encryption didn’t take effect.');
  }
}

/// Turns the open database [db] back into a plain file.
Future<void> decryptDatabase(
  MeshDatabase db,
  File file,
  DbKeyStore store,
) async {
  await _withSafetyCopy(
    db,
    file,
    () => db.customStatement("PRAGMA rekey = ''"),
  );
  if (!isPlainDatabase(file)) {
    throw const DbEncryptionException('Decrypting didn’t take effect.');
  }
  await store.delete();
}
