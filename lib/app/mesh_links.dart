import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../radio/radio.dart';

/// A shareable MeshCore link, as documented in MeshCore's `docs/qr_codes.md`
/// and understood by the official app.
sealed class MeshLink {
  const MeshLink();

  /// Reads a `meshcore://` link, ignoring surrounding spaces. Returns null
  /// for anything else or a link with missing or bad parts.
  static MeshLink? parse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != 'meshcore' || uri.path != '/add') {
      return null;
    }
    final q = uri.queryParameters;
    try {
      switch (uri.host) {
        case 'channel':
          final name = q['name'];
          final secret = fromHex(q['secret'] ?? '');
          if (name == null || name.isEmpty || secret.length != 16) return null;
          return ChannelLink(name: name, secret: secret);
        case 'contact':
          final name = q['name'];
          final key = q['public_key'];
          if (name == null || key == null || key.length != 64) return null;
          return ContactLink(
            name: name,
            publicKey: PublicKey.fromHex(key),
            type: NodeType.fromByte(int.tryParse(q['type'] ?? '') ?? 1),
          );
      }
    } on FormatException {
      return null; // bad hex
    }
    return null;
  }

  String get url;
}

final class ChannelLink extends MeshLink {
  ChannelLink({required this.name, required List<int> secret})
    : secret = Uint8List.fromList(secret);

  final String name;
  final Uint8List secret;

  @override
  String get url => Uri(
    scheme: 'meshcore',
    host: 'channel',
    path: '/add',
    queryParameters: {'name': name, 'secret': toHex(secret)},
  ).toString();
}

final class ContactLink extends MeshLink {
  const ContactLink({
    required this.name,
    required this.publicKey,
    required this.type,
  });

  final String name;
  final PublicKey publicKey;
  final NodeType type;

  @override
  String get url => Uri(
    scheme: 'meshcore',
    host: 'contact',
    path: '/add',
    queryParameters: {
      'name': name,
      'public_key': publicKey.hex,
      'type': '${type.value}',
    },
  ).toString();
}

/// The well-known key of the built-in Public channel.
final publicChannelSecret = fromHex('8b3387e9c5cdea6ac9e5edbaa115cd72');

/// Normalises a hashtag channel name: a leading `#`, lowercase, no spaces.
String hashtagName(String input) {
  final bare = input.trim().replaceFirst(RegExp('^#+'), '').toLowerCase();
  return '#${bare.replaceAll(RegExp(r'\s+'), '-')}';
}

/// A hashtag channel's key: the first 16 bytes of SHA-256 of its name,
/// `#` included. Anyone who knows the name can read the channel.
Uint8List hashtagSecret(String name) => Uint8List.fromList(
  sha256.convert(utf8.encode(hashtagName(name))).bytes.sublist(0, 16),
);

/// A fresh random key for a private channel.
Uint8List randomChannelSecret([Random? random]) {
  final rng = random ?? Random.secure();
  return Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
}
