import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';

void main() {
  late FakeRadioLink link;
  late RadioSession session;

  setUp(() {
    link = FakeRadioLink();
    session = RadioSession(link);
  });

  tearDown(() => session.close());

  test(
    'start identifies the app, reads device info and sets the clock',
    () async {
      link.onSend = (frame) => switch (frame[0]) {
        CommandCode.appStart => [selfInfoFrame(name: 'Base')],
        CommandCode.deviceQuery => [deviceInfoFrame(maxChannels: 40)],
        CommandCode.setDeviceTime => [okFrame()],
        _ => [],
      };
      final start = await session.start(now: DateTime.utc(2026, 11, 5));
      expect(start.self.name, 'Base');
      expect(start.device.maxChannels, 40);
      expect(link.sentCodes, [
        CommandCode.appStart,
        CommandCode.deviceQuery,
        CommandCode.setDeviceTime,
      ]);
      expect(link.sent.last.sublist(1), u32(1793836800));
    },
  );

  test('start tolerates a radio clock that is already ahead', () async {
    link.onSend = (frame) => switch (frame[0]) {
      CommandCode.appStart => [selfInfoFrame()],
      CommandCode.deviceQuery => [deviceInfoFrame()],
      _ => [errorFrame(RadioErrorCode.illegalArgument)],
    };
    await expectLater(session.start(), completes);
  });

  test('commands go out one at a time, in order', () async {
    final replies = <Completer<void>>[];
    link.onSend = (frame) {
      replies.add(Completer());
      return [];
    };
    final first = session.request<CurrentTime>(const GetDeviceTime());
    final second = session.run(const SendSelfAdvert());
    await pumpEventQueue();
    expect(link.sent, hasLength(1), reason: 'second waits for first reply');

    link.emit([ResponseCode.currentTime, ...u32(42)]);
    expect((await first).unixSeconds, 42);
    await pumpEventQueue();
    expect(link.sentCodes, [
      CommandCode.getDeviceTime,
      CommandCode.sendSelfAdvert,
    ]);

    link.emit(okFrame());
    await second;
  });

  test('error replies become RadioRejected and the queue moves on', () async {
    link.onSend = (frame) => frame[0] == CommandCode.removeContact
        ? [errorFrame(RadioErrorCode.notFound)]
        : [okFrame()];
    final key = PublicKey(testKey);
    await expectLater(
      session.run(RemoveContact(key)),
      throwsA(
        isA<RadioRejected>().having(
          (e) => e.code,
          'code',
          RadioErrorCode.notFound,
        ),
      ),
    );
    await session.run(ResetPath(key));
  });

  test('a reply of the wrong type is reported, not cast', () async {
    link.onSend = (_) => [okFrame()];
    await expectLater(
      session.request<SelfInfo>(const AppStart()),
      throwsA(isA<RadioUnexpectedReply>()),
    );
  });

  test('disabled features are reported', () async {
    link.onSend = (_) => [
      [ResponseCode.disabled],
    ];
    await expectLater(
      session.run(const SendSelfAdvert()),
      throwsA(isA<RadioFeatureDisabled>()),
    );
  });

  test('a silent radio times out and the next command still runs', () {
    fakeAsync((async) {
      final link = FakeRadioLink();
      final session = RadioSession(link, timeout: const Duration(seconds: 5));
      Object? error;
      session
          .run(const SendSelfAdvert())
          .then<void>((_) {}, onError: (Object e) => error = e);
      var secondDone = false;
      session.run(const SendSelfAdvert()).then((_) => secondDone = true);

      async.elapse(const Duration(seconds: 5));
      expect(error, isA<RadioTimeout>());
      expect(link.sent, hasLength(2));

      link.emit(okFrame());
      async.flushMicrotasks();
      expect(secondDone, isTrue);
      session.close();
    });
  });

  test('contacts arrive as start, entries, end', () async {
    link.onSend = (frame) => [
      [ResponseCode.contactsStart, ...u32(2)],
      contactFrame('Alice', keyByte: 1, lastModified: 10),
      contactFrame('Bob', keyByte: 2, lastModified: 20),
      [ResponseCode.endOfContacts, ...u32(20)],
    ];
    final sync = await session.fetchContacts(since: 5);
    expect(sync.contacts.map((c) => c.name), ['Alice', 'Bob']);
    expect(sync.newestModified, 20);
    expect(link.sent.single, [CommandCode.getContacts, ...u32(5)]);
  });

  test('a long contact list only times out if a gap is too long', () {
    fakeAsync((async) {
      final link = FakeRadioLink();
      final session = RadioSession(link, timeout: const Duration(seconds: 5));
      ContactSync? result;
      session.fetchContacts().then((r) => result = r);
      async.flushMicrotasks();

      link.emit([ResponseCode.contactsStart, ...u32(3)]);
      for (var i = 0; i < 3; i++) {
        async.elapse(const Duration(seconds: 4));
        link.emit(contactFrame('Node $i', keyByte: i + 1));
      }
      async.elapse(const Duration(seconds: 4));
      link.emit([ResponseCode.endOfContacts, ...u32(1)]);
      async.flushMicrotasks();
      expect(result?.contacts, hasLength(3));
      session.close();
    });
  });

  test('channels stop at the first slot the radio does not have', () async {
    link.onSend = (frame) => switch (frame[1]) {
      0 => [channelInfoFrame(0, 'Public')],
      1 => [channelInfoFrame(1, '')],
      _ => [errorFrame(RadioErrorCode.notFound)],
    };
    final channels = await session.fetchChannels(8);
    expect(channels, hasLength(2));
    expect(channels[0].name, 'Public');
    expect(channels[1].isEmpty, isTrue);
  });

  test('messages waiting triggers a sync that drains the queue', () async {
    final queued = [
      channelMessageFrame('Ridge: hello'),
      channelMessageFrame('Ridge: again'),
    ];
    link.onSend = (frame) => frame[0] == CommandCode.syncNextMessage
        ? [
            queued.isEmpty ? [ResponseCode.noMoreMessages] : queued.removeAt(0),
          ]
        : [];
    final received = <ReplyFrame>[];
    session.messages.listen(received.add);
    final pushes = <PushFrame>[];
    session.pushes.listen(pushes.add);

    link.emit([PushCode.messagesWaiting]);
    await pumpEventQueue();

    expect(pushes.single, isA<MessagesWaiting>());
    expect(received.cast<ChannelMessage>().map((m) => m.senderAndBody.body), [
      'hello',
      'again',
    ]);
    expect(link.sentCodes, List.filled(3, CommandCode.syncNextMessage));
  });

  test('pushes arriving mid-request do not disturb the reply', () async {
    link.onSend = (_) => [
      [PushCode.advert, ...testKey],
      okFrame(),
    ];
    final pushes = <PushFrame>[];
    session.pushes.listen(pushes.add);
    await session.run(const SendSelfAdvert());
    expect(pushes.single, isA<AdvertHeard>());
  });

  test('unknown frames and stray replies go to unhandled', () async {
    final unhandled = <RadioFrame>[];
    session.unhandled.listen(unhandled.add);
    link.emit([0x7E]);
    link.emit(okFrame());
    await pumpEventQueue();
    expect(unhandled[0], isA<UnknownFrame>());
    expect(unhandled[1], isA<OkReply>());
  });

  test(
    'a dropped link fails the request in flight and everything queued',
    () async {
      final first = session.run(const SendSelfAdvert());
      final second = session.run(const SendSelfAdvert());
      await pumpEventQueue();
      link.drop();
      await expectLater(first, throwsA(isA<RadioDisconnected>()));
      await expectLater(second, throwsA(isA<RadioDisconnected>()));
      expect(session.isClosed, isTrue);
      await expectLater(
        session.run(const SendSelfAdvert()),
        throwsA(isA<RadioDisconnected>()),
      );
    },
  );

  test('an oversized command fails without blocking the queue', () async {
    link.onSend = (_) => [okFrame()];
    expect(
      () => session.run(
        SendChannelText(channel: 0, text: 'x' * 300, timestamp: 0),
      ),
      throwsArgumentError,
    );
    await session.run(const SendSelfAdvert());
  });

  test('send-only commands expect no reply', () async {
    await session.sendOnly(const Reboot());
    expect(link.sentCodes, [CommandCode.reboot]);
  });
}
