import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/scripted_radio.dart';

List<int> _directFrame(String text, {int keyByte = 1, int ts = 100}) => [
  ResponseCode.contactMessageV3,
  0,
  0,
  0,
  ...List.filled(6, keyByte),
  0,
  0,
  ...u32(ts),
  ...utf8.encode(text),
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeRadioLink link;
  late ScriptedRadio radio;
  late MeshDatabase db;
  late MeshStore store;
  late MeshSync sync;
  final now = DateTime.utc(2026, 11, 5);

  setUp(() {
    link = FakeRadioLink();
    radio = ScriptedRadio(link);
    db = MeshDatabase.inMemory();
    store = MeshStore(db);
    sync = MeshSync(
      RadioSession(link),
      store,
      contactRefreshDelay: Duration.zero,
    );
  });

  tearDown(() async {
    await sync.stop();
    await db.close();
  });

  test(
    'start stores the radio, contacts, channels and queued messages',
    () async {
      radio.queue.add(_directFrame('missed you'));
      final connected = await sync.start(now: now);

      expect(connected.self.name, 'Base');
      expect(connected.device.maxChannels, 3);
      final key = connected.key;
      expect((await store.watchContacts(key).first).map((c) => c.name), [
        'Alice',
      ]);
      expect((await store.watchChannels(key).first).map((c) => c.name), [
        'Public',
        '#trail',
      ]);
      final thread = await store
          .watchThread(key, Threads.direct('01' * 32))
          .first;
      expect(thread.single.body, 'missed you');
    },
  );

  test('a reconnect only asks for contacts changed since last time', () async {
    await sync.start(now: now);
    await sync.stop();

    // Connect again over a fresh link to the same radio.
    final link2 = FakeRadioLink();
    final radio2 = ScriptedRadio(link2);
    final again = MeshSync(RadioSession(link2), store);
    await again.start(now: now);
    await again.stop();
    expect(radio.getContactsSince, [null]);
    expect(radio2.getContactsSince, [10]);
  });

  test('messages arriving later are saved as they come', () async {
    final key = (await sync.start(now: now)).key;
    radio.queue.add(channelMessageFrame('Ridge: summit at noon', channel: 1));
    link.emit([PushCode.messagesWaiting]);
    await pumpEventQueue();

    final thread = await store.watchThread(key, Threads.channel(1)).first;
    expect(thread.single.senderName, 'Ridge');
    expect(thread.single.body, 'summit at noon');
  });

  test(
    'a direct message goes pending, sent, then delivered on its ack',
    () async {
      final key = (await sync.start(now: now)).key;
      final alice = PublicKey(List.filled(32, 1));
      await sync.sendDirect(alice, 'on my way', now: now);

      var message =
          (await store.watchThread(key, Threads.direct(alice.hex)).first)
              .single;
      expect(message.status, MessageStatus.sent);
      expect(message.ackCode, 0x1234);
      expect(link.sent.last[0], CommandCode.sendTextMessage);

      link.emit([PushCode.sendConfirmed, ...u32(0x1234), ...u32(800)]);
      await pumpEventQueue();
      message = (await store.watchThread(key, Threads.direct(alice.hex)).first)
          .single;
      expect(message.status, MessageStatus.delivered);
    },
  );

  test(
    'a refused message is stored as failed and the error reaches the caller',
    () async {
      final key = (await sync.start(now: now)).key;
      radio.refuseText = true;
      final alice = PublicKey(List.filled(32, 1));
      await expectLater(
        sync.sendDirect(alice, 'hello', now: now),
        throwsA(isA<RadioRejected>()),
      );
      final message =
          (await store.watchThread(key, Threads.direct(alice.hex)).first)
              .single;
      expect(message.status, MessageStatus.failed);
    },
  );

  test(
    'a message too long for the radio is refused before it is stored',
    () async {
      final key = (await sync.start(now: now)).key;
      expect(
        () => sync.sendChannel(0, 'x' * 300, now: now),
        throwsArgumentError,
      );
      await pumpEventQueue();
      expect(await store.watchThread(key, Threads.channel(0)).first, isEmpty);
    },
  );

  test('channel messages end at sent', () async {
    final key = (await sync.start(now: now)).key;
    await sync.sendChannel(1, 'heading down', now: now);
    final message =
        (await store.watchThread(key, Threads.channel(1)).first).single;
    expect(message.status, MessageStatus.sent);
    expect(message.outgoing, isTrue);
  });

  test(
    'a node the radio did not add goes to heard nearby, not contacts',
    () async {
      final key = (await sync.start(now: now)).key;
      final bob = contactFrame('Bob', keyByte: 2)..[0] = PushCode.newAdvert;
      link.emit(bob);
      await pumpEventQueue();
      expect((await store.watchContacts(key).first).map((c) => c.name), [
        'Alice',
      ]);
      expect((await store.watchDiscovered(key).first).map((d) => d.name), [
        'Bob',
      ]);

      link.emit([PushCode.contactDeleted, ...List.filled(32, 1)]);
      await pumpEventQueue();
      expect(await store.watchContacts(key).first, isEmpty);
    },
  );

  test('heard nearby leaves out nodes that are already contacts', () async {
    final key = (await sync.start(now: now)).key;
    final alice = contactFrame('Alice', keyByte: 1)..[0] = PushCode.newAdvert;
    link.emit(alice);
    await pumpEventQueue();
    expect(await store.watchDiscovered(key).first, isEmpty);
  });

  test('a burst of adverts triggers one contact refresh', () {
    fakeAsync((async) {
      final link = FakeRadioLink();
      final radio = ScriptedRadio(link);
      final db = MeshDatabase.inMemory();
      final sync = MeshSync(RadioSession(link), MeshStore(db));
      sync.start(now: now);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 10));
      expect(radio.getContactsSince, hasLength(1));

      for (var i = 0; i < 5; i++) {
        link.emit([PushCode.advert, ...List.filled(32, 1)]);
        async.elapse(const Duration(milliseconds: 100));
      }
      async.elapse(const Duration(seconds: 3));
      expect(radio.getContactsSince, hasLength(2));
      sync.stop();
      db.close();
      async.flushMicrotasks();
    });
  });
}
