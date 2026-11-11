/// Signed channel posts: a post goes out as normal text, followed by a
/// channel datagram carrying the radio's Ed25519 signature over it. Apps that
/// don't know the datagram just see the post.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// MeshCore's developer datagram type.
const signedPostDataType = 0xFFFF;

const _magic = [0x4E, 0x58, 0x01]; // "NX", version 1

/// What a signature covers: a fixed tag, which channel (by key hash, so a
/// signature can't be replayed on another channel), the post's time, and
/// the post exactly as receivers see it ("Name: text").
Uint8List signedBytes({
  required Uint8List channelSecret,
  required int sentAt,
  required String post,
}) {
  final out = BytesBuilder()
    ..add(ascii.encode('NXS1'))
    ..add(sha256.convert(channelSecret).bytes.sublist(0, 4))
    ..add(_u32(sentAt))
    ..add(utf8.encode(post));
  return out.toBytes();
}

/// A signature for a channel post.
typedef PostSignature = ({int sentAt, Uint8List signer, Uint8List signature});

Uint8List encodePostSignature(PostSignature s) =>
    (BytesBuilder()
          ..add(_magic)
          ..add(_u32(s.sentAt))
          ..add(s.signer)
          ..add(s.signature))
        .toBytes();

/// [payload] as a signature, or null if it isn't one.
PostSignature? decodePostSignature(Uint8List payload) {
  if (payload.length != 3 + 4 + 32 + 64) return null;
  for (var i = 0; i < 3; i++) {
    if (payload[i] != _magic[i]) return null;
  }
  final sentAt = ByteData.sublistView(
    payload,
    3,
    7,
  ).getUint32(0, Endian.little);
  return (
    sentAt: sentAt,
    signer: Uint8List.sublistView(payload, 7, 39),
    signature: Uint8List.sublistView(payload, 39),
  );
}

/// Whether [s] is a valid signature by its signer over [message].
bool verifyPostSignature(PostSignature s, Uint8List message) {
  try {
    return ed.verify(ed.PublicKey(s.signer), message, s.signature);
  } on Object {
    return false;
  }
}

List<int> _u32(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];
