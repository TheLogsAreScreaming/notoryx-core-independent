/// The setting that encrypts chat history on this device.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'connection.dart';

final dbKeyStoreProvider = Provider<DbKeyStore>(
  (ref) => const SecureDbKeyStore(),
);

/// Whether the database is encrypted. An error means this device has no
/// usable secure storage, so the option isn't offered.
class DbEncryption extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      await ref.read(dbKeyStoreProvider).read() != null;

  /// Encrypts or decrypts now. Throws [DbEncryptionException] on failure.
  Future<void> set(bool on) async {
    final db = ref.read(databaseProvider);
    final file = await meshDatabaseFile();
    final keys = ref.read(dbKeyStoreProvider);
    if (on) {
      await encryptDatabase(db, file, keys);
    } else {
      await decryptDatabase(db, file, keys);
    }
    state = AsyncData(on);
  }
}

final dbEncryptionProvider = AsyncNotifierProvider<DbEncryption, bool>(
  DbEncryption.new,
);
