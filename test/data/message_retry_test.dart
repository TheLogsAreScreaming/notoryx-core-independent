import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/schema_rollback.dart';
import '../support/scripted_radio.dart';

final _alice = PublicKey(List.filled(32, 1));
final _now = DateTime.utc(2026, 11, 5);

/// Runs [body] on a fake clock with a connected, synced radio.
void _withRadio(
  void Function(
    FakeAsync async,
    FakeRadioLink link,
    ScriptedRadio radio,
    MeshSync sync,
    MeshStore store,
    String key,
  )
  body,
) {
  fakeAsync((async) {
    final link = FakeRadioLink();
    final radio = ScriptedRadio(link);
    final db = MeshDatabase.inMemory();
    final store = MeshStore(db);
    final sync = MeshSync(RadioSession(link), store);
    String? key;
    sync.start(now: _now).then((r) => key = r.key);
    async.flushMicrotasks();
    async.elapse(const Duration(milliseconds: 50));
    body(async, link, radio, sync, store, key!);
    sync.stop();
    async.flushMicrotasks();
    db.close();
    async.flushMicrotasks();
  });
}

Message _only(FakeAsync async, MeshStore store, String key) {
  Message? message;
  Object? error;
  store
      .threadSnapshot(key, Threads.direct(_alice.hex))
      .then<void>(
        (m) => message = m.single,
        onError: (Object e) {
          error = e;
        },
      );
  async.flushMicrotasks();
  if (error != null) fail('$error');
  return message!;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('no ack: 4 direct tries, drop the route, 4 floods, then failed', () {
    _withRadio((async, link, radio, sync, store, key) {
      sync.sendDirect(_alice, 'are you there', now: _now);
      async.flushMicrotasks();
      expect(radio.textAttempts, [0]);
      expect(sync.retrying, hasLength(1));

      // Each try waits the radio's 5 s estimate plus 2 s.
      async.elapse(const Duration(seconds: 7 * 8 + 1));

      expect(radio.textAttempts, [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(radio.pathResets, 1);
      final message = _only(async, store, key);
      expect(message.status, MessageStatus.failed);
      expect(message.attempts, 8);
      expect(sync.retrying, isEmpty);
    });
  });

  test('an ack for an earlier try still counts and stops the resends', () {
    _withRadio((async, link, radio, sync, store, key) {
      sync.sendDirect(_alice, 'hello', now: _now);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 15)); // tries 0, 1 and 2 sent
      expect(radio.textAttempts, [0, 1, 2]);

      // The ack for try 1 arrives late.
      link.emit([PushCode.sendConfirmed, ...u32(0x1234 + 1), ...u32(900)]);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));

      expect(radio.textAttempts, [0, 1, 2], reason: 'no more tries');
      expect(_only(async, store, key).status, MessageStatus.delivered);
      expect(sync.retrying, isEmpty);
    });
  });

  test('a contact with no route floods straight away, 4 times', () {
    _withRadio((async, link, radio, sync, store, key) {
      radio.routed = false;
      sync.sendDirect(_alice, 'anyone?', now: _now);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      expect(radio.textAttempts, [0, 1, 2, 3]);
      expect(radio.pathResets, 0);
      expect(_only(async, store, key).status, MessageStatus.failed);
    });
  });

  test('stop trying marks it failed and sends nothing more', () {
    _withRadio((async, link, radio, sync, store, key) {
      int? id;
      sync.sendDirect(_alice, 'oops', now: _now).then((v) => id = v);
      async.flushMicrotasks();
      sync.stopTrying(id!);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      expect(radio.textAttempts, [0]);
      expect(_only(async, store, key).status, MessageStatus.failed);
    });
  });

  test('resend continues the attempt count so packets stay unique', () {
    _withRadio((async, link, radio, sync, store, key) {
      int? id;
      sync.sendDirect(_alice, 'again', now: _now).then((v) => id = v);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      expect(_only(async, store, key).status, MessageStatus.failed);

      radio.routed = true;
      sync.resend(id!);
      async.flushMicrotasks();
      expect(radio.textAttempts.last, 8);
      expect(_only(async, store, key).status, MessageStatus.sent);

      link.emit([PushCode.sendConfirmed, ...u32(0x1234 + 8), ...u32(900)]);
      async.flushMicrotasks();
      expect(_only(async, store, key).status, MessageStatus.delivered);
    });
  });

  test('disconnecting fails messages still waiting for an ack', () async {
    final link = FakeRadioLink();
    ScriptedRadio(link);
    final db = MeshDatabase.inMemory();
    final store = MeshStore(db);
    final sync = MeshSync(RadioSession(link), store);
    final key = (await sync.start(now: _now)).key;
    await sync.sendDirect(_alice, 'brb', now: _now);
    expect(sync.retrying, hasLength(1));

    await sync.stop().timeout(const Duration(seconds: 2));
    final message = (await store.threadSnapshot(
      key,
      Threads.direct(_alice.hex),
    )).single;
    expect(message.status, MessageStatus.failed);
    await db.close();
  });

  test('a message pending from an earlier run is failed on connect', () async {
    final db = MeshDatabase.inMemory();
    final store = MeshStore(db);
    final link = FakeRadioLink();
    ScriptedRadio(link);
    final self = decodeFrame(selfInfoFrame(name: 'Base')) as SelfInfo;
    await store.rememberRadio(self);
    await store.saveOutgoing(
      self.publicKey.hex,
      thread: Threads.direct(_alice.hex),
      body: 'left behind',
      sentAt: 1,
    );

    final sync = MeshSync(RadioSession(link), store);
    final key = (await sync.start(now: _now)).key;
    final message =
        (await store.watchThread(key, Threads.direct(_alice.hex)).first).single;
    expect(message.status, MessageStatus.failed);
    await sync.stop();
    await db.close();
  });

  test('text over 160 bytes is refused before anything is stored', () async {
    final db = MeshDatabase.inMemory();
    final store = MeshStore(db);
    final link = FakeRadioLink();
    ScriptedRadio(link);
    final sync = MeshSync(RadioSession(link), store);
    final key = (await sync.start(now: _now)).key;
    expect(
      () => sync.sendDirect(_alice, 'x' * 161, now: _now),
      throwsArgumentError,
    );
    await pumpEventQueue();
    expect(
      await store.watchThread(key, Threads.direct(_alice.hex)).first,
      isEmpty,
    );
    await sync.stop();
    await db.close();
  });

  test('a long message keeps its attempt byte within 0 to 3', () {
    _withRadio((async, link, radio, sync, store, key) {
      sync.sendDirect(_alice, 'y' * 159, now: _now);
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      expect(radio.textAttempts, [0, 1, 2, 3, 0, 1, 2, 3]);
    });
  });

  test('upgrading a version 2 database adds the settings table', () async {
    final dir = await Directory.systemTemp.createTemp('notoryx_db');
    final file = File('${dir.path}/v2.sqlite');
    var db = MeshDatabase(NativeDatabase(file));
    await db.customSelect('SELECT 1').get();
    await rollBackTo(db, 2);
    await db.close();

    db = MeshDatabase(NativeDatabase(file));
    final store = MeshStore(db);
    await store.saveSetting('k', 'v');
    expect(await store.setting('k'), 'v');
    await store.removeSetting('k');
    expect(await store.setting('k'), isNull);
    await db.close();
    await dir.delete(recursive: true);
  });

  test('upgrading a version 1 database adds the attempts column', () async {
    final dir = await Directory.systemTemp.createTemp('notoryx_db');
    final file = File('${dir.path}/v1.sqlite');
    var db = MeshDatabase(NativeDatabase(file));
    await db.customSelect('SELECT 1').get();
    await rollBackTo(db, 1);
    await db.close();

    db = MeshDatabase(NativeDatabase(file));
    final columns = await db
        .customSelect("SELECT name FROM pragma_table_info('messages')")
        .map((row) => row.read<String>('name'))
        .get();
    expect(columns, contains('attempts'));
    await db.close();
    await dir.delete(recursive: true);
  });
}
