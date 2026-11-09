import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/spam_filter.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  var nextId = 0;
  Message post(
    String body, {
    String? sender = 'Bob',
    int minute = 0,
    bool outgoing = false,
    MessageKind kind = MessageKind.channel,
  }) => Message(
    id: ++nextId,
    radioKey: 'r',
    kind: kind,
    thread: 'c:1',
    outgoing: outgoing,
    body: body,
    senderName: sender,
    sentAt: 0,
    storedAt: minute * 60000,
    status: MessageStatus.values.first,
    attempts: 0,
    textType: 0,
  );

  Set<int> ids(Iterable<Message> m) => {for (final x in m) x.id};

  test('the third copy within the window is hidden', () {
    final posts = [
      post('Buy now', minute: 0),
      post('  buy   NOW ', minute: 5),
      post('Buy now', minute: 10),
      post('Buy now', minute: 15),
    ];
    expect(spamRepeats(posts), ids(posts.sublist(2)));
  });

  test('copies spread out over time stay', () {
    expect(
      spamRepeats([
        post('Net at 7', minute: 0),
        post('Net at 7', minute: 40),
        post('Net at 7', minute: 80),
      ]),
      isEmpty,
    );
  });

  test('different senders are counted apart', () {
    expect(
      spamRepeats([
        post('Hi', sender: 'A'),
        post('Hi', sender: 'B'),
        post('Hi', sender: 'C'),
      ]),
      isEmpty,
    );
  });

  test('an SOS is never hidden, however often it repeats', () {
    expect(
      spamRepeats([
        for (var i = 0; i < 6; i++) post('SOS broken leg', minute: i * 5),
      ]),
      isEmpty,
    );
  });

  test('a mention of you is never hidden', () {
    expect(
      spamRepeats([
        for (var i = 0; i < 4; i++) post('@[Sam] answer', minute: i),
      ], myName: 'Sam'),
      isEmpty,
    );
  });

  test('your own posts, direct messages and unnamed posts stay', () {
    expect(
      spamRepeats([
        for (var i = 0; i < 4; i++) post('Mine', outgoing: true),
        for (var i = 0; i < 4; i++) post('DM', kind: MessageKind.direct),
        for (var i = 0; i < 4; i++) post('Anon', sender: null),
      ]),
      isEmpty,
    );
  });
}
