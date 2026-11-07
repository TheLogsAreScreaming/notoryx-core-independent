import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/reactions.dart';
import 'package:notoryx_core/data/data.dart';

var _nextId = 1;

Message _msg(String body, {String? from, bool outgoing = false}) => Message(
  id: _nextId++,
  radioKey: 'r',
  kind: MessageKind.channel,
  thread: 'c:1',
  outgoing: outgoing,
  body: body,
  senderName: from,
  sentAt: 0,
  storedAt: 0,
  status: outgoing ? MessageStatus.sent : MessageStatus.received,
  textType: 0,
  attempts: 0,
);

String _sender(Message m) => m.outgoing ? 'Me' : m.senderName ?? '?';

void main() {
  group('text forms', () {
    test('a reaction quotes the start of the message', () {
      expect(reactionText('👍', 'On my way'), '👍 re "On my way"');
      final long = reactionText(
        '❤️',
        'Summit at noon, then down the west ridge',
      );
      expect(long, '❤️ re "Summit at noon, then dow…"');
      final parsed = parseReaction(long)!;
      expect(parsed.emoji, '❤️');
      expect(parsed.cut, isTrue);
      expect(
        parsed.matches('Summit at noon, then down the west ridge'),
        isTrue,
      );
      expect(parsed.matches('Summit at noon'), isFalse);
    });

    test('line breaks are flattened in the quote', () {
      final text = reactionText('👍', 'one\ntwo');
      expect(text, '👍 re "one two"');
      expect(parseReaction(text)!.matches('one\ntwo'), isTrue);
    });

    test('words are not mistaken for reactions', () {
      expect(parseReaction('ok re "lunch"'), isNull);
      expect(parseReaction('👍 re ""'), isNull);
      expect(parseReaction('👍 thanks'), isNull);
    });

    test('a reply starts with a mention', () {
      expect(replyText('Ridge', 'see you there'), '@[Ridge] see you there');
      final parsed = parseReply('@[Ridge] see you there')!;
      expect(parsed.name, 'Ridge');
      expect(parsed.text, 'see you there');
      expect(parseReply('@[Ridge]'), isNull);
      expect(parseReply('hi @[Ridge]'), isNull);
    });
  });

  group('chatItems', () {
    test('folds reactions into the message they react to', () {
      final items = chatItems([
        _msg('On my way', from: 'Ridge'),
        _msg('Arrived', from: 'Ann'),
        _msg('👍 re "On my way"', from: 'Ann'),
        _msg('👍 re "On my way"', outgoing: true),
        _msg('😂 re "Arrived"', from: 'Ridge'),
      ], senderOf: _sender);
      expect(items.map((i) => i.message.body), ['On my way', 'Arrived']);
      final thumbs = items[0].reactions.single;
      expect(thumbs.emoji, '👍');
      expect(thumbs.who, ['Ann', 'Me']);
      expect(thumbs.mine, isTrue);
      expect(items[1].reactions.single.who, ['Ridge']);
    });

    test('a reaction to the newest matching message only', () {
      final items = chatItems([
        _msg('OK', from: 'Ridge'),
        _msg('OK', from: 'Ann'),
        _msg('👍 re "OK"', outgoing: true),
      ], senderOf: _sender);
      expect(items[0].reactions, isEmpty);
      expect(items[1].reactions, hasLength(1));
    });

    test('a reaction with nothing to land on stays a message', () {
      final items = chatItems([
        _msg('👍 re "something older"', from: 'Ridge'),
      ], senderOf: _sender);
      expect(items.single.message.body, '👍 re "something older"');
    });

    test('a reply links to the newest earlier message from that person', () {
      final items = chatItems([
        _msg('first', from: 'Ridge'),
        _msg('lunch at the hut?', from: 'Ridge'),
        _msg('@[Ridge] yes please', outgoing: true),
        _msg('@[Nobody] hello', from: 'Ann'),
      ], senderOf: _sender);
      expect(items[2].replyTo!.body, 'lunch at the hut?');
      expect(items[2].replyText, 'yes please');
      expect(items[3].replyTo, isNull, reason: 'nobody to link to');
      expect(items[3].replyText, isNull);
    });

    test('a reaction can quote a reply as other apps show it', () {
      final items = chatItems([
        _msg('lunch?', from: 'Ridge'),
        _msg('@[Ridge] yes', from: 'Ann'),
        _msg('❤️ re "@[Ridge] yes"', from: 'Ridge'),
      ], senderOf: _sender);
      expect(items, hasLength(2));
      expect(items[1].reactions.single.emoji, '❤️');
    });
  });
}
