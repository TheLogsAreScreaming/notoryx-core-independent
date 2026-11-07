import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/radio_frames.dart';
import '../support/schema_rollback.dart';

ChannelMessage _channel(String text, int ts, {int slot = 0}) => decodeFrame(
  channelMessageFrame(text, channel: slot)..replaceRange(7, 11, u32(ts)),
) as ChannelMessage;

ContactMessage _direct(String text, int ts) => decodeFrame([
  ResponseCode.contactMessageV3,
  0,
  0,
  0,
  ...List.filled(6, 7),
  0,
  0,
  ...u32(ts),
  ...utf8.encode(text),
]) as ContactMessage;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;
  late MeshStore store;
  late String radio;

  setUp(() async {
    db = MeshDatabase.inMemory();
    store = MeshStore(db);
    final self = decodeFrame(selfInfoFrame()) as SelfInfo;
    radio = self.publicKey.hex;
    await store.rememberRadio(self);
  });

  tearDown(() => db.close());

  test('incoming messages are unread until the thread is read', () async {
    await store.saveIncoming(radio, _channel('A: one', 1));
    await store.saveIncoming(radio, _channel('A: two', 2));
    await store.saveIncoming(radio, _direct('hi', 3));
    await store.saveOutgoing(
      radio,
      thread: Threads.channel(0),
      body: 'mine',
      sentAt: 4,
    );

    expect(await store.watchUnreadCounts(radio).first, {
      Threads.channel(0): 2,
      Threads.direct('070707070707'): 1,
    });

    await store.markRead(radio, Threads.channel(0));
    expect(await store.watchUnreadCounts(radio).first, {
      Threads.direct('070707070707'): 1,
    });

    await store.saveIncoming(radio, _channel('A: three', 5));
    expect((await store.watchUnreadCounts(radio).first)[Threads.channel(0)], 1);
  });

  test('marking an empty thread read does nothing', () async {
    await store.markRead(radio, Threads.channel(3));
    expect(await store.watchUnreadCounts(radio).first, isEmpty);
  });

  test('muting is per thread and can be undone', () async {
    await store.setMuted(radio, Threads.channel(0), true);
    expect(await store.isMuted(radio, Threads.channel(0)), isTrue);
    expect(await store.isMuted(radio, Threads.channel(1)), isFalse);
    expect(await store.watchMuted(radio).first, {Threads.channel(0)});

    await store.saveIncoming(radio, _channel('A: still counted', 1));
    expect((await store.watchUnreadCounts(radio).first)[Threads.channel(0)], 1);

    await store.setMuted(radio, Threads.channel(0), false);
    expect(await store.watchMuted(radio).first, isEmpty);
  });

  test('upgrading to version 4 counts existing messages as read', () async {
    final dir = await Directory.systemTemp.createTemp('notoryx_db');
    final file = File('${dir.path}/v3.sqlite');
    var db3 = MeshDatabase(NativeDatabase(file));
    final store3 = MeshStore(db3);
    final self = decodeFrame(selfInfoFrame()) as SelfInfo;
    await store3.rememberRadio(self);
    await store3.saveIncoming(self.publicKey.hex, _channel('A: old', 1));
    await rollBackTo(db3, 3);
    await db3.close();

    db3 = MeshDatabase(NativeDatabase(file));
    final upgraded = MeshStore(db3);
    expect(await upgraded.watchUnreadCounts(self.publicKey.hex).first, isEmpty);
    await upgraded.saveIncoming(self.publicKey.hex, _channel('A: new', 2));
    expect(
      (await upgraded
          .watchUnreadCounts(self.publicKey.hex)
          .first)[Threads.channel(0)],
      1,
    );
    await db3.close();
    await dir.delete(recursive: true);
  });

  test(
    'upgrading to version 5 adds heard nearby and forces a full contact sync',
    () async {
      final dir = await Directory.systemTemp.createTemp('notoryx_db');
      final file = File('${dir.path}/v4.sqlite');
      var db4 = MeshDatabase(NativeDatabase(file));
      final store4 = MeshStore(db4);
      final self = decodeFrame(selfInfoFrame()) as SelfInfo;
      await store4.rememberRadio(self);
      await store4.saveContacts(self.publicKey.hex, (
        contacts: [],
        newestModified: 99,
      ));
      await rollBackTo(db4, 4);
      await db4.close();

      db4 = MeshDatabase(NativeDatabase(file));
      final upgraded = MeshStore(db4);
      expect((await upgraded.radio(self.publicKey.hex))?.contactsSince, 0);
      expect(await upgraded.watchDiscovered(self.publicKey.hex).first, isEmpty);
      await db4.close();
      await dir.delete(recursive: true);
    },
  );
}
