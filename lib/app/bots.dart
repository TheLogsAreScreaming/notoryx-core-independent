/// Automatic replies. Off until you turn them on, and held back hard,
/// because every reply takes airtime on a mesh other people share.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'blocking.dart';
import 'chat_send.dart';
import 'connection.dart';
import 'notifications.dart';
import 'safety.dart';

const botSetting = 'bot_settings';

/// Most automatic replies sent in any hour.
const botHourlyLimit = 20;

/// A message older than this is backlog from being away, not a live
/// question, so it gets no reply.
const botMaxAge = Duration(minutes: 10);

const botDirectCooldown = Duration(minutes: 1);
const botChannelCooldown = Duration(minutes: 5);

/// How long a rule with no trigger (an away message) stays quiet per chat.
const botAwayCooldown = Duration(hours: 1);

/// When a message contains [trigger], send [reply].
final class BotRule {
  const BotRule({
    required this.id,
    required this.trigger,
    required this.reply,
    this.onChannels = false,
  });

  factory BotRule.fromJson(Map<String, Object?> json) => BotRule(
    id: json['id']! as int,
    trigger: json['trigger']! as String,
    reply: json['reply']! as String,
    onChannels: json['channels'] == true,
  );

  final int id;

  /// Matched anywhere in the message, ignoring case. Empty means every
  /// direct message, which is an away message.
  final String trigger;

  /// May use `{name}` and `{time}`.
  final String reply;

  /// Also answers on channels. An away message never does.
  final bool onChannels;

  bool get isAway => trigger.trim().isEmpty;

  Map<String, Object?> toJson() => {
    'id': id,
    'trigger': trigger,
    'reply': reply,
    'channels': onChannels,
  };
}

final class BotSettings {
  const BotSettings({this.enabled = false, this.rules = const []});

  factory BotSettings.fromJson(String? raw) {
    if (raw == null) return const BotSettings();
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return BotSettings(
        enabled: json['enabled'] == true,
        rules: [
          for (final r in json['rules']! as List<Object?>)
            BotRule.fromJson(r! as Map<String, Object?>),
        ],
      );
    } on Object {
      return const BotSettings();
    }
  }

  final bool enabled;
  final List<BotRule> rules;

  String toJson() => jsonEncode({
    'enabled': enabled,
    'rules': [for (final r in rules) r.toJson()],
  });
}

/// Whether [text] is SOS or check-in traffic. A bot must never answer it:
/// any reply tells the sender's app that a person has answered their SOS.
bool isSafetyTraffic(String text) =>
    RegExp(r'\bsos\b', caseSensitive: false).hasMatch(text) ||
    text.startsWith('Check-in:') ||
    text.startsWith('Missed check-in');

/// Decides what to reply, and remembers what it has sent.
final class BotEngine {
  final _lastSent = <String, DateTime>{};
  final _sentTimes = <DateTime>[];

  /// The reply to [m], or null for none. A non-null result counts as sent.
  String? decide(
    BotSettings settings,
    Message m, {
    required String senderName,
    required bool blocked,
    required DateTime now,
  }) {
    if (!settings.enabled || m.outgoing || blocked || m.textType != 0) {
      return null;
    }
    if (isSafetyTraffic(m.body)) return null;
    final sentAt = DateTime.fromMillisecondsSinceEpoch(m.sentAt * 1000);
    if (now.difference(sentAt) > botMaxAge) return null;
    final isChannel = m.kind == MessageKind.channel;
    // Only a full key can be replied to directly.
    if (!isChannel && m.thread.length != 2 + 64) return null;
    _sentTimes.removeWhere(
      (t) => now.difference(t) >= const Duration(hours: 1),
    );
    if (_sentTimes.length >= botHourlyLimit) return null;

    for (final rule in settings.rules) {
      if (rule.isAway ? isChannel : isChannel && !rule.onChannels) continue;
      final trigger = rule.trigger.trim().toLowerCase();
      if (!rule.isAway && !m.body.toLowerCase().contains(trigger)) continue;
      final key = '${rule.id}:${m.thread}';
      final wait = rule.isAway
          ? botAwayCooldown
          : isChannel
          ? botChannelCooldown
          : botDirectCooldown;
      final last = _lastSent[key];
      if (last != null && now.difference(last) < wait) continue;
      final text = _fill(rule.reply, senderName, now);
      if (text.isEmpty || utf8.encode(text).length > maxDirectTextBytes) {
        continue;
      }
      _lastSent[key] = now;
      _sentTimes.add(now);
      return text;
    }
    return null;
  }

  String _fill(String reply, String name, DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return reply
        .replaceAll('{name}', name)
        .replaceAll('{time}', '${two(now.hour)}:${two(now.minute)}')
        .trim();
  }
}

/// The saved settings.
class Bots extends AsyncNotifier<BotSettings> {
  @override
  Future<BotSettings> build() async =>
      BotSettings.fromJson(await ref.read(storeProvider).setting(botSetting));

  Future<void> _save(BotSettings s) async {
    await ref.read(storeProvider).saveSetting(botSetting, s.toJson());
    state = AsyncData(s);
  }

  Future<void> setEnabled(bool on) async =>
      _save(BotSettings(enabled: on, rules: (await future).rules));

  Future<void> addRule({
    required String trigger,
    required String reply,
    required bool onChannels,
  }) async {
    final s = await future;
    await _save(
      BotSettings(
        enabled: s.enabled,
        rules: [
          ...s.rules,
          BotRule(
            id: ref.read(safetyClockProvider)().microsecondsSinceEpoch,
            trigger: trigger.trim(),
            reply: reply.trim(),
            onChannels: onChannels && trigger.trim().isNotEmpty,
          ),
        ],
      ),
    );
  }

  Future<void> removeRule(int id) async {
    final s = await future;
    await _save(
      BotSettings(
        enabled: s.enabled,
        rules: [
          for (final r in s.rules)
            if (r.id != id) r,
        ],
      ),
    );
  }
}

final botsProvider = AsyncNotifierProvider<Bots, BotSettings>(Bots.new);

/// Answers incoming messages while a radio is connected.
final botRunnerProvider = Provider<void>((ref) {
  final engine = BotEngine();
  StreamSubscription<Message>? incoming;

  Future<void> handle(Connected state, Message m) async {
    final settings = await ref.read(botsProvider.future);
    if (!settings.enabled) return;
    final store = ref.read(storeProvider);
    final blocks = await readBlockList(store);
    final name = m.kind == MessageKind.channel
        ? m.senderName ?? 'there'
        : (await chatLinkFor(store, state.radio.key, m.thread)).title;
    final reply = engine.decide(
      settings,
      m,
      senderName: name,
      blocked: blocks.blocks(m),
      now: ref.read(safetyClockProvider)(),
    );
    if (reply == null) return;
    try {
      await sendToThread(state, store, m.thread, reply);
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('auto-reply: $e');
    }
  }

  void listenTo(RadioConnectionState state) {
    unawaited(incoming?.cancel());
    incoming = state is Connected
        ? state.sync.incoming.listen((m) => unawaited(handle(state, m)))
        : null;
  }

  ref.onDispose(() => unawaited(incoming?.cancel()));
  listenTo(ref.read(connectionProvider));
  ref.listen(connectionProvider, (_, next) => listenTo(next));
});
