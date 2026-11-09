import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/mesh_links.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/scripted_radio.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeRadioLink link;
  late ScriptedRadio radio;
  late MeshDatabase db;
  late MeshStore store;
  late MeshSync sync;
  late String key;

  setUp(() async {
    link = FakeRadioLink();
    radio = ScriptedRadio(link);
    db = MeshDatabase.inMemory();
    store = MeshStore(db);
    sync = MeshSync(RadioSession(link), store);
    key = (await sync.start(now: DateTime.utc(2026, 11, 6))).key;
  });

  tearDown(() async {
    await sync.stop();
    await db.close();
  });

  Future<List<String>> channelNames() async => [
    for (final c in await store.watchChannels(key).first) '${c.slot}:${c.name}',
  ];

  test('a hashtag channel goes in the first free slot', () async {
    final slot = await sync.addChannel('#hiking', hashtagSecret('#hiking'));
    expect(slot, 2);
    expect(radio.channels[2]!.$2, hashtagSecret('#hiking'));
    expect(await channelNames(), ['0:Public', '1:#trail', '2:#hiking']);
  });

  test('adding a channel the radio already has returns its slot', () async {
    final slot = await sync.addChannel('Trail', List.filled(16, 0x11));
    expect(slot, 1);
    expect(radio.channels, hasLength(2));
  });

  test('a full radio says so', () async {
    await sync.addChannel('#a', hashtagSecret('#a'));
    await expectLater(
      sync.addChannel('#b', hashtagSecret('#b')),
      throwsA(isA<ChannelsFull>()),
    );
  });

  test('rename keeps the key; leave empties the slot', () async {
    await sync.renameChannel(1, '#trail-talk');
    expect(radio.channels[1]!.$1, '#trail-talk');
    expect(radio.channels[1]!.$2, List.filled(16, 0x11));
    await sync.leaveChannel(1);
    expect(radio.channels.containsKey(1), isFalse);
    expect(await channelNames(), ['0:Public']);
  });

  test('a contact from a link is added on the radio and here', () async {
    final carol = PublicKey(List.filled(32, 3));
    await store.saveDiscovered(
      key,
      (decodeFrame(contactFrame('Carol', keyByte: 3)) as ContactEntry).contact,
    );
    await sync.addContact(publicKey: carol, name: 'Carol', type: NodeType.chat);

    final names = (await store.watchContacts(key).first).map((c) => c.name);
    expect(names, containsAll(['Alice', 'Carol']));
    expect(
      await store.watchDiscovered(key).first,
      isEmpty,
      reason: 'no longer just heard nearby',
    );
  });

  test('remove and favourite change the radio too', () async {
    final alice = PublicKey(List.filled(32, 1));
    await sync.setFavourite(alice, true);
    expect((await store.contact(key, alice.hex))!.flags & 1, 1);
    await sync.setFavourite(alice, false);
    expect((await store.contact(key, alice.hex))!.flags & 1, 0);

    await sync.removeContact(alice);
    expect(radio.contacts, isEmpty);
    expect(await store.watchContacts(key).first, isEmpty);
  });

  test('command line permission can be given and taken back', () async {
    final alice = PublicKey(List.filled(32, 1));
    await sync.setFavourite(alice, true);
    await sync.setRemoteCommandsAllowed(alice, allowed: true);
    var row = (await store.contact(key, alice.hex))!;
    expect(row.flags & contactFlagRemoteCommands, contactFlagRemoteCommands);
    expect(row.flags & 1, 1, reason: 'still a favourite');

    await sync.setRemoteCommandsAllowed(alice, allowed: false);
    row = (await store.contact(key, alice.hex))!;
    expect(row.flags & contactFlagRemoteCommands, 0);
    expect(row.flags & 1, 1);
  });

  test('forgetting a last advert keeps everything else', () async {
    final alice = PublicKey(List.filled(32, 1));
    await sync.setFavourite(alice, true);
    final before = (await store.contact(key, alice.hex))!;
    await sync.forgetLastAdvert(alice);
    final after = (await store.contact(key, alice.hex))!;
    expect(after.lastAdvert, 0);
    expect(after.name, before.name);
    expect(after.flags, before.flags);
    expect(after.outPathLength, before.outPathLength);
  });

  test('adverts go out zero-hop or flooded', () async {
    await sync.sendAdvert();
    await sync.sendAdvert(flood: true);
    expect(radio.adverts, [false, true]);
  });
}
