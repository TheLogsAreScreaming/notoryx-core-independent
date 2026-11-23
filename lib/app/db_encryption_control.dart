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
    await ref
        .read(storeProvider)
        .saveSetting(dbEncryptionChoiceSetting, on ? 'on' : 'off');
    state = AsyncData(on);
  }
}

/// Encrypts the database once at startup where that's the default (phones
/// and Macs) and the person hasn't chosen otherwise. Never throws.
final dbEncryptionDefaultProvider = FutureProvider<EncryptionDefault>((
  ref,
) async {
  try {
    final result = await applyEncryptionDefault(
      ref.read(databaseProvider),
      await meshDatabaseFile(),
      ref.read(dbKeyStoreProvider),
    );
    if (result == EncryptionDefault.encrypted) {
      ref.invalidate(dbEncryptionProvider);
    }
    return result;
  } on Object {
    return EncryptionDefault.notHere;
  }
});

final dbEncryptionProvider = AsyncNotifierProvider<DbEncryption, bool>(
  DbEncryption.new,
);
