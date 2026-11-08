import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/blocking.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/radio_frames.dart';

Message _m(
  String body, {
  MessageKind kind = MessageKind.channel,
  String? from,
  String thread = 'c:1',
  bool outgoing = false,
}) => Message(
  id: 1,
  radioKey: 'r',
  kind: kind,
  thread: thread,
  outgoing: outgoing,
  body: body,
  senderName: from,
  sentAt: 0,
  storedAt: 0,
  status: MessageStatus.received,
  attempts: 0,
  textType: 0,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('mentions', () {
    expect(mentions('@[Base] you there?', 'Base'), isTrue);
    expect(mentions('hey @base', 'Base'), isTrue);
    expect(mentions('@basecamp tonight', 'Base'), isFalse);
    expect(mentions('base camp', 'Base'), isFalse);
    expect(mentions('@[Base]', null), isFalse);
  });

  test('what a block list hides', () {
    const list = BlockList(names: {'Spammy'}, keys: {'aa'});
    expect(list.blocks(_m('buy', from: 'Spammy')), isTrue);
    expect(list.blocks(_m('hi', from: 'Ridge')), isFalse);
    expect(
      list.blocks(_m('hi', kind: MessageKind.direct, thread: 'd:aa')),
      isTrue,
    );
    expect(
      list.blocks(_m('mine', from: 'Spammy', outgoing: true)),
      isFalse,
      reason: 'your own messages are never hidden',
    );
  });

  test(
    'blocked senders are left out of unread counts and chat lists',
    () async {
      final db = MeshDatabase.inMemory();
      final store = MeshStore(db);
      final self = decodeFrame(selfInfoFrame()) as SelfInfo;
      await store.rememberRadio(self);
      final key = self.publicKey.hex;
      for (final text in ['Ridge: one', 'Spammy: buy', 'Spammy: now']) {
        await store.saveIncoming(
          key,
          decodeFrame(channelMessageFrame(text, channel: 1)) as ReplyFrame,
        );
      }
      final container = await store.watchUnreadCounts(key).first;
      expect(container['c:1'], 3);

      await store.saveSetting(MeshStore.blockedNamesSetting, '["Spammy"]');
      expect((await store.watchUnreadCounts(key).first)['c:1'], 1);
      final latest = await store.watchConversations(key).first;
      expect(latest.single.body, 'one', reason: 'newest unblocked message');
      // Still stored, so unblocking brings them back.
      expect(await store.watchThread(key, 'c:1').first, hasLength(3));
      await db.close();
    },
  );
}
