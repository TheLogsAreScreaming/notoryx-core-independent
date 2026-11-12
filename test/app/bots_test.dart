import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/bots.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  final now = DateTime(2026, 11, 9, 12);
  final thread = 'd:${'ab' * 32}';

  Message message(
    String body, {
    String? on,
    MessageKind kind = MessageKind.direct,
    bool outgoing = false,
    Duration age = Duration.zero,
    int textType = 0,
  }) => Message(
    id: 1,
    radioKey: 'r',
    kind: kind,
    thread: on ?? thread,
    outgoing: outgoing,
    body: body,
    sentAt: now.subtract(age).millisecondsSinceEpoch ~/ 1000,
    storedAt: now.millisecondsSinceEpoch,
    status: MessageStatus.received,
    attempts: 0,
    textType: textType,
  );

  const ping = BotRule(id: 1, trigger: 'ping', reply: 'pong {name}');
  const on = BotSettings(enabled: true, rules: [ping]);

  String? ask(
    BotEngine e,
    Message m, {
    BotSettings s = on,
    bool blocked = false,
    DateTime? at,
  }) => e.decide(s, m, senderName: 'Sam', blocked: blocked, now: at ?? now);

  test('answers a match, ignoring case, and fills in the name', () {
    expect(ask(BotEngine(), message('PING?')), 'pong Sam');
    expect(ask(BotEngine(), message('hello')), isNull);
  });

  test('stays silent when off, blocked, outgoing, old or console', () {
    expect(
      ask(BotEngine(), message('ping'), s: const BotSettings(rules: [ping])),
      isNull,
    );
    expect(ask(BotEngine(), message('ping'), blocked: true), isNull);
    expect(ask(BotEngine(), message('ping', outgoing: true)), isNull);
    expect(
      ask(BotEngine(), message('ping', age: const Duration(minutes: 11))),
      isNull,
    );
    expect(ask(BotEngine(), message('ping', textType: 1)), isNull);
  });

  test('never answers SOS or check-in traffic, even if it matches', () {
    const any = BotSettings(
      enabled: true,
      rules: [BotRule(id: 2, trigger: '', reply: 'away')],
    );
    for (final text in [
      'SOS - I need help.',
      'sos (2) ping',
      'Check-in: OK.',
      'Missed check-in (due 07:05).',
    ]) {
      expect(ask(BotEngine(), message(text), s: any), isNull, reason: text);
    }
    expect(ask(BotEngine(), message('sossage'), s: any), 'away');
  });

  test('channels only when the rule allows, and away is direct only', () {
    final post = message('ping', on: 'c:1', kind: MessageKind.channel);
    expect(ask(BotEngine(), post), isNull);
    const open = BotSettings(
      enabled: true,
      rules: [BotRule(id: 3, trigger: 'ping', reply: 'pong', onChannels: true)],
    );
    expect(ask(BotEngine(), post, s: open), 'pong');
    const away = BotSettings(
      enabled: true,
      rules: [BotRule(id: 4, trigger: '', reply: 'away', onChannels: true)],
    );
    expect(ask(BotEngine(), post, s: away), isNull);
  });

  test('waits between repeats', () {
    final e = BotEngine();
    expect(ask(e, message('ping')), isNotNull);
    expect(
      ask(e, message('ping'), at: now.add(const Duration(seconds: 30))),
      isNull,
    );
    expect(
      ask(
        e,
        message('ping', age: const Duration(minutes: -2)),
        at: now.add(const Duration(minutes: 2)),
      ),
      isNotNull,
    );
  });

  test('stops at the hourly limit', () {
    final e = BotEngine();
    for (var i = 0; i < botHourlyLimit; i++) {
      final other = 'd:${i.toRadixString(16).padLeft(2, '0') * 32}';
      expect(ask(e, message('ping', on: other)), isNotNull);
    }
    expect(ask(e, message('ping', on: 'd:${'ff' * 32}')), isNull);
  });

  test('settings survive saving, and bad data turns it off', () {
    final back = BotSettings.fromJson(on.toJson());
    expect(back.enabled, isTrue);
    expect(back.rules.single.reply, 'pong {name}');
    expect(BotSettings.fromJson('nonsense').enabled, isFalse);
  });

  test('commands answer in direct chats, and only ticked channels', () {
    const on = BotSettings(enabled: true, commands: true, commandChannels: {2});
    expect(ask(BotEngine(), message('!moon'), s: on), contains('lit'));
    expect(
      ask(
        BotEngine(),
        message('!moon', on: 'c:1', kind: MessageKind.channel),
        s: on,
      ),
      isNull,
    );
    expect(
      ask(
        BotEngine(),
        message('!moon', on: 'c:2', kind: MessageKind.channel),
        s: on,
      ),
      contains('lit'),
    );
    const off = BotSettings(enabled: true);
    expect(ask(BotEngine(), message('!moon'), s: off), isNull);
  });

  test('commands keep to the cooldown and never answer SOS', () {
    const on = BotSettings(enabled: true, commands: true);
    final e = BotEngine();
    expect(ask(e, message('!ping'), s: on), startsWith('pong'));
    expect(
      ask(e, message('!ping'), s: on, at: now.add(const Duration(seconds: 10))),
      isNull,
    );
    expect(ask(BotEngine(), message('!ping SOS'), s: on), isNull);
  });

  test('command settings survive saving', () {
    const s = BotSettings(
      enabled: true,
      commands: true,
      commandChannels: {3, 5},
    );
    final back = BotSettings.fromJson(s.toJson());
    expect(back.commands, isTrue);
    expect(back.commandChannels, {3, 5});
  });
}
