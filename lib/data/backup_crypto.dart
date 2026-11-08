/// The encrypted backup file format.
///
/// ```text
/// magic       8 bytes  "NOTORYXB"
/// format      1 byte   1
/// iterations  4 bytes  PBKDF2 rounds, big-endian
/// salt       16 bytes
/// nonce      12 bytes
/// sealed      rest     AES-256-GCM ciphertext + 16-byte tag
/// ```
///
/// The key is PBKDF2-HMAC-SHA256 of the password. The 41 header bytes are
/// authenticated as associated data, so a changed header fails to open.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const backupMagic = 'NOTORYXB';
const backupFormat = 1;

/// PBKDF2 rounds for new backups (OWASP's 2023 figure for SHA-256 is
/// 600,000; this is lower because it runs in pure Dart on phones, and still
/// makes each password guess cost tens of milliseconds).
const backupIterations = 210000;

const _headerLength = 8 + 1 + 4 + 16 + 12;

/// Why a backup file couldn't be opened.
final class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Seals [plain] with [password]. [salt] and [nonce] are random unless
/// given (for tests).
Uint8List sealBackup(
  List<int> plain,
  String password, {
  int iterations = backupIterations,
  List<int>? salt,
  List<int>? nonce,
}) {
  final random = Random.secure();
  List<int> bytes(int n) => [for (var i = 0; i < n; i++) random.nextInt(256)];
  final s = Uint8List.fromList(salt ?? bytes(16));
  final iv = Uint8List.fromList(nonce ?? bytes(12));
  final header = BytesBuilder()
    ..add(ascii.encode(backupMagic))
    ..addByte(backupFormat)
    ..add(_u32(iterations))
    ..add(s)
    ..add(iv);
  final head = header.toBytes();
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(
        KeyParameter(_key(password, s, iterations)),
        128,
        iv,
        head,
      ),
    );
  final sealed = cipher.process(Uint8List.fromList(plain));
  return (BytesBuilder()
        ..add(head)
        ..add(sealed))
      .toBytes();
}

/// Opens a backup sealed by [sealBackup]. Throws [BackupException] when it
/// isn't a backup or the password is wrong.
Uint8List openBackup(List<int> file, String password) {
  if (file.length < _headerLength + 16 ||
      ascii.decode(file.sublist(0, 8), allowInvalid: true) != backupMagic) {
    throw const BackupException('That isn’t a NOTORYX backup file.');
  }
  if (file[8] != backupFormat) {
    throw const BackupException(
      'This backup was made by a newer version of the app. Update it first.',
    );
  }
  final data = ByteData.sublistView(Uint8List.fromList(file));
  final iterations = data.getUint32(9);
  if (iterations < 1000 || iterations > 10000000) {
    throw const BackupException('That backup file is damaged.');
  }
  final salt = Uint8List.fromList(file.sublist(13, 29));
  final iv = Uint8List.fromList(file.sublist(29, _headerLength));
  final head = Uint8List.fromList(file.sublist(0, _headerLength));
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(
        KeyParameter(_key(password, salt, iterations)),
        128,
        iv,
        head,
      ),
    );
  try {
    return cipher.process(Uint8List.fromList(file.sublist(_headerLength)));
  } on InvalidCipherTextException {
    throw const BackupException(
      'Wrong password, or the file has been changed.',
    );
  }
}

Uint8List _key(String password, Uint8List salt, int iterations) {
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, 32));
  return kdf.process(Uint8List.fromList(utf8.encode(password)));
}

List<int> _u32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];
