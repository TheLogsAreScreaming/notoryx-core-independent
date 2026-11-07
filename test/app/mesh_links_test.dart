import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/mesh_links.dart';
import 'package:notoryx_core/radio/radio.dart';

void main() {
  test('reads the documented channel link', () {
    final link = MeshLink.parse(
      'meshcore://channel/add?name=Public&secret=8b3387e9c5cdea6ac9e5edbaa115cd72',
    ) as ChannelLink;
    expect(link.name, 'Public');
    expect(link.secret, publicChannelSecret);
  });

  test('reads the documented contact link', () {
    final link = MeshLink.parse(
      'meshcore://contact/add?name=Example+Contact&public_key=9cd8fcf22a47333b591d96a2b848b73f457b1bb1a3ea2453a885f9e5787765b1&type=1',
    ) as ContactLink;
    expect(link.name, 'Example Contact');
    expect(link.publicKey.hex, startsWith('9cd8fcf2'));
    expect(link.type, NodeType.chat);
  });

  test('links round-trip, with names that need encoding', () {
    final channel = ChannelLink(
      name: 'Trail & Camp',
      secret: List.filled(16, 7),
    );
    final back = MeshLink.parse(channel.url) as ChannelLink;
    expect(back.name, 'Trail & Camp');
    expect(back.secret, channel.secret);

    final contact = ContactLink(
      name: 'Ridge RPT',
      publicKey: PublicKey(List.filled(32, 9)),
      type: NodeType.repeater,
    );
    final c = MeshLink.parse(contact.url) as ContactLink;
    expect(
      (c.name, c.publicKey, c.type),
      (contact.name, contact.publicKey, NodeType.repeater),
    );
  });

  test('anything else is not a link', () {
    for (final text in [
      '',
      'hello',
      'https://meshcore.io',
      'meshcore://channel/add?name=X&secret=zz',
      'meshcore://channel/add?name=X&secret=8b33',
      'meshcore://contact/add?name=X&public_key=abc',
      'meshcore://contact/remove?name=X',
    ]) {
      expect(MeshLink.parse(text), isNull, reason: text);
    }
  });

  test('hashtag keys match the MeshCore docs', () {
    // docs/companion_protocol.md: "#test" has key 9cd8fcf22a47333b591d96a2b848b73f
    expect(toHex(hashtagSecret('#test')), '9cd8fcf22a47333b591d96a2b848b73f');
    expect(toHex(hashtagSecret('Test')), toHex(hashtagSecret('#test')));
    expect(hashtagName('  ##Trail Talk '), '#trail-talk');
  });

  test('private channel keys are 16 random bytes', () {
    final a = randomChannelSecret(Random(1));
    final b = randomChannelSecret(Random(2));
    expect(a, hasLength(16));
    expect(a, isNot(equals(b)));
  });
}
