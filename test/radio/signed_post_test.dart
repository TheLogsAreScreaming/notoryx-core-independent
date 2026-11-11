import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/protocol/commands.dart';
import 'package:notoryx_core/radio/protocol/signed_post.dart';

void main() {
  final keys = ed.generateKey();
  final secret = Uint8List.fromList(List.generate(16, (i) => i));
  const sentAt = 1700000000;

  PostSignature signedFor(String post) {
    final bytes = signedBytes(
      channelSecret: secret,
      sentAt: sentAt,
      post: post,
    );
    return (
      sentAt: sentAt,
      signer: Uint8List.fromList(keys.publicKey.bytes),
      signature: Uint8List.fromList(ed.sign(keys.privateKey, bytes)),
    );
  }

  test('a good signature checks out, through encoding', () {
    final s = decodePostSignature(
      encodePostSignature(signedFor('Sam: SOS - I need help.')),
    )!;
    expect(s.sentAt, sentAt);
    expect(
      verifyPostSignature(
        s,
        signedBytes(
          channelSecret: secret,
          sentAt: sentAt,
          post: 'Sam: SOS - I need help.',
        ),
      ),
      isTrue,
    );
  });

  test('a changed post, time or channel fails', () {
    final s = signedFor('Sam: SOS - I need help.');
    Uint8List bytes({
      String post = 'Sam: SOS - I need help.',
      int at = sentAt,
      Uint8List? key,
    }) => signedBytes(channelSecret: key ?? secret, sentAt: at, post: post);
    expect(verifyPostSignature(s, bytes(post: 'Sam: all fine')), isFalse);
    expect(verifyPostSignature(s, bytes(at: sentAt + 1)), isFalse);
    expect(
      verifyPostSignature(s, bytes(key: Uint8List(16))),
      isFalse,
      reason: 'replayed on another channel',
    );
  });

  test('anything else in the datagram is ignored', () {
    expect(decodePostSignature(Uint8List(103)), isNull);
    expect(decodePostSignature(Uint8List(10)), isNull);
  });

  test('it fits in one channel datagram', () {
    final payload = encodePostSignature(signedFor('x'));
    expect(payload.length, lessThanOrEqualTo(165));
    final frame = SendChannelData(
      channel: 2,
      dataType: signedPostDataType,
      payload: payload,
    ).encode();
    expect(frame.sublist(0, 5), [62, 2, 0xFF, 0xFF, 0xFF]);
  });
}
