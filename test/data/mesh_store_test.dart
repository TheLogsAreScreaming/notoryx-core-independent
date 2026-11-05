import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/radio_frames.dart';

RadioContact _contact(String name, int keyByte, {int lastModified = 1}) =>
    (decodeFrame(
      contactFrame(name, keyByte: keyByte, lastModified: lastModified),
    ) as ContactEntry).contact;

ContactMessage _direct(String text, {int keyByte = 7, int ts = 1000}) =>
    decodeFrame([
      ResponseCode.contactMessageV3,
      8,
      0,
      0,
      ...List.filled(6, keyByte),
      0,
      TextType.plain.value,
      ...u32(ts),
      ...utf8.encode(text),
    ]) as ContactMessage;

ChannelMessage _channel(String text, {int slot = 0, int ts = 1000}) =>
    decodeFrame(
      channelMessageFrame(text, channel: slot)..replaceRange(7, 11, u32(ts)),
    ) as ChannelMessage;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;
  late MeshStore store;
  late String radio;
  var now = DateTime.utc(2026, 11, 5, 12);

  setUp(() async {
    db = MeshDatabase.inMemory();
    store = MeshStore(db, clock: () => now);
    final self = decodeFrame(selfInfoFrame(name: 'Base')) as SelfInfo;
    radio = self.publicKey.hex;
    await store.rememberRadio(self);
  });

  tearDown(() => db.close());

  test('remembers radios and refreshes the name on reconnect', () async {
    now = now.add(const Duration(hours: 1));
    await store.rememberRadio(
      decodeFrame(selfInfoFrame(name: 'Base Camp')) as SelfInfo,
    );
    final saved = await store.radio(radio);
    expect(saved?.name, 'Base Camp');
    expect(saved?.lastConnectedAt, now.millisecondsSinceEpoch);
    expect(saved?.contactsSince, 0);
  });

  test('a full contact sync replaces the list and moves the cursor', () async {
    await store.saveContacts(radio, (
      contacts: [_contact('Bob', 2, lastModified: 20), _contact('Alice', 1)],
      newestModified: 20,
    ));
    expect((await store.watchContacts(radio).first).map((c) => c.name), [
      'Alice',
      'Bob',
    ]);
    expect((await store.radio(radio))?.contactsSince, 20);

    // Bob was removed on the radio; a full sync drops him here too.
    await store.saveContacts(radio, (
      contacts: [_contact('Alice', 1, lastModified: 30)],
      newestModified: 30,
    ), since: 0);
    expect((await store.watchContacts(radio).first).map((c) => c.name), [
      'Alice',
    ]);
  });

  test('a partial sync only adds and updates', () async {
    await store.saveContacts(radio, (
      contacts: [_contact('Alice', 1), _contact('Bob', 2)],
      newestModified: 5,
    ));
    await store.saveContacts(radio, (
      contacts: [_contact('Bobby', 2, lastModified: 9)],
      newestModified: 9,
    ), since: 5);
    expect((await store.watchContacts(radio).first).map((c) => c.name), [
      'Alice',
      'Bobby',
    ]);
    expect((await store.radio(radio))?.contactsSince, 9);
  });

  test('the sync cursor never moves backwards', () async {
    await store.saveContacts(radio, (contacts: [], newestModified: 50));
    await store.saveContacts(radio, (
      contacts: [],
      newestModified: 0,
    ), since: 50);
    expect((await store.radio(radio))?.contactsSince, 50);
  });

  test('single contact add and remove, for pushes', () async {
    final carol = _contact('Carol', 3);
    await store.saveContact(radio, carol);
    expect(await store.watchContacts(radio).first, hasLength(1));
    await store.removeContact(radio, carol.publicKey);
    expect(await store.watchContacts(radio).first, isEmpty);
  });

  test('channels keep only named slots', () async {
    await store.saveChannels(radio, [
      decodeFrame(channelInfoFrame(0, 'Public')) as ChannelInfo,
      decodeFrame(channelInfoFrame(1, '')) as ChannelInfo,
      decodeFrame(channelInfoFrame(2, '#hiking')) as ChannelInfo,
    ]);
    final slots = await store.watchChannels(radio).first;
    expect(slots.map((c) => (c.slot, c.name)), [(0, 'Public'), (2, '#hiking')]);
  });

  test(
    'incoming direct messages thread by full key once the contact is known',
    () async {
      final unknown = await store.saveIncoming(radio, _direct('hi', ts: 1));
      expect(unknown?.thread, Threads.direct('070707070707'));

      await store.saveContact(radio, _contact('Dana', 7));
      final known = await store.saveIncoming(radio, _direct('again', ts: 2));
      expect(known?.thread, Threads.direct('07' * 32));
      expect(known?.snr, 2.0);
      expect(known?.status, MessageStatus.received);
    },
  );

  test('the same message delivered twice is stored once', () async {
    expect(await store.saveIncoming(radio, _direct('dup')), isNotNull);
    expect(await store.saveIncoming(radio, _direct('dup')), isNull);
    expect(await store.saveIncoming(radio, _channel('Ridge: dup')), isNotNull);
    expect(await store.saveIncoming(radio, _channel('Ridge: dup')), isNull);
  });

  test('channel messages keep the sender name apart from the text', () async {
    final saved = await store.saveIncoming(
      radio,
      _channel('Ridge: trail is clear', slot: 2),
    );
    expect(saved?.thread, Threads.channel(2));
    expect(saved?.senderName, 'Ridge');
    expect(saved?.body, 'trail is clear');
  });

  test('outgoing direct message: pending, sent, delivered once', () async {
    final thread = Threads.direct('07' * 32);
    final id = await store.saveOutgoing(
      radio,
      thread: thread,
      body: 'on my way',
      sentAt: 1000,
    );
    var messages = await store.watchThread(radio, thread).first;
    expect(messages.single.status, MessageStatus.pending);
    expect(messages.single.kind, MessageKind.direct);

    await store.markSent(id, ackCode: 0xBEEF, flooded: true);
    expect(await store.markDelivered(radio, 0xBEEF), isTrue);
    expect(await store.markDelivered(radio, 0xBEEF), isFalse);

    messages = await store.watchThread(radio, thread).first;
    expect(messages.single.status, MessageStatus.delivered);
    expect(messages.single.flooded, isTrue);
  });

  test('failed sends are marked', () async {
    final id = await store.saveOutgoing(
      radio,
      thread: Threads.channel(0),
      body: 'hello all',
      sentAt: 1,
    );
    await store.markFailed(id);
    final message =
        (await store.watchThread(radio, Threads.channel(0)).first).single;
    expect(message.status, MessageStatus.failed);
    expect(message.kind, MessageKind.channel);
  });

  test('threads list oldest first and update live', () async {
    final thread = Threads.channel(0);
    final updates = store.watchThread(radio, thread).map((m) => m.length);
    final seen = <int>[];
    final sub = updates.listen(seen.add);
    await pumpEventQueue();
    await store.saveIncoming(radio, _channel('A: one', ts: 1));
    await pumpEventQueue();
    await store.saveIncoming(radio, _channel('A: two', ts: 2));
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [0, 1, 2]);

    final bodies = (await store.watchThread(radio, thread).first).map(
      (m) => m.body,
    );
    expect(bodies, ['one', 'two']);
  });

  test('data from different radios stays apart', () async {
    final other = decodeFrame(
      selfInfoFrame(name: 'Car')..replaceRange(4, 36, List.filled(32, 0xEE)),
    ) as SelfInfo;
    await store.rememberRadio(other);
    await store.saveContact(other.publicKey.hex, _contact('Eve', 5));
    expect(await store.watchContacts(radio).first, isEmpty);
    expect(await store.watchContacts(other.publicKey.hex).first, hasLength(1));
  });
}
