import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/scripted_radio.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final repeater = PublicKey(List.filled(32, 0x42));
  late FakeRadioLink link;
  late ScriptedRadio radio;
  late MeshDatabase db;
  late MeshStore store;
  late MeshSync sync;
  late String key;

  setUp(() async {
    link = FakeRadioLink();
    radio = ScriptedRadio(link)
      ..servers[0x42] = (password: 'secret', status: repeaterStatusBlock())
      // Replies are filed under the contact's full key, as in real use.
      ..contacts.add(
        contactFrame(
          'Hill RPT',
          keyByte: 0x42,
          type: NodeType.repeater,
          lastModified: 11,
        ),
      );
    db = MeshDatabase.inMemory();
    store = MeshStore(db);
    sync = MeshSync(
      RadioSession(link),
      store,
      serverReplyFloor: const Duration(milliseconds: 200),
    );
    key = (await sync.start(now: DateTime.utc(2026, 11, 7))).key;
  });

  tearDown(() async {
    await sync.stop();
    await db.close();
  });

  test('login with the right password gives the role', () async {
    final result = await sync.login(repeater, 'secret');
    expect(result, isA<LoggedIn>());
    expect((result as LoggedIn).role, ServerRole.admin);
  });

  test('a wrong password gets no reply, which is reported as such', () async {
    expect(await sync.login(repeater, 'nope'), isA<LoginNoReply>());
  });

  test('status comes back parsed', () async {
    final status = await sync.requestStatus(repeater);
    expect(status?.batteryMillivolts, 4100);
    expect(
      await sync.requestStatus(PublicKey(List.filled(32, 9))),
      isNull,
      reason: 'a server that does not answer',
    );
  });

  test('console commands and replies stay out of the chat', () async {
    await sync.sendCommand(repeater, 'ver');
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final thread = Threads.direct(repeater.hex);
    final console = await store.threadSnapshot(key, thread, console: true);
    expect(console.map((m) => (m.outgoing, m.body)), [
      (true, 'ver'),
      (false, 'v1.18.0'),
    ]);
    expect(await store.threadSnapshot(key, thread), isEmpty);
    expect(await store.watchUnreadCounts(key).first, isEmpty);
  });

  test('room posts keep who wrote them', () async {
    final room = PublicKey(List.filled(32, 0x55));
    radio.queue.add([
      ResponseCode.contactMessageV3,
      0,
      0,
      0,
      ...room.prefix(),
      0,
      TextType.signedPlain.value,
      ...u32(1700000002),
      1,
      2,
      3,
      4,
      ...utf8.encode('trail is clear'),
    ]);
    link.emit([PushCode.messagesWaiting]);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final posts = await store.threadSnapshot(
      key,
      Threads.direct(toHex(room.prefix())),
    );
    expect(posts.single.authorPrefix, '01020304');
    expect(posts.single.body, 'trail is clear');
  });
}
