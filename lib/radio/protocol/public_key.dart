import 'dart:typed_data';

import 'bytes.dart';
import 'codes.dart';

/// A node's 32-byte public key, its identity on the mesh.
final class PublicKey {
  PublicKey(List<int> bytes) : bytes = Uint8List.fromList(bytes) {
    if (bytes.length != publicKeySize) {
      throw ArgumentError.value(bytes.length, 'bytes', 'must be 32 bytes');
    }
  }

  factory PublicKey.fromHex(String hex) => PublicKey(fromHex(hex));

  final Uint8List bytes;

  String get hex => toHex(bytes);

  /// The first [length] bytes, which is how the radio names a node in
  /// messages (6 bytes) and in logins (6 bytes).
  Uint8List prefix([int length = 6]) => Uint8List.sublistView(bytes, 0, length);

  /// Whether this key starts with [prefix].
  bool startsWith(List<int> prefix) {
    if (prefix.length > bytes.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) => other is PublicKey && other.hex == hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'PublicKey($hex)';
}
