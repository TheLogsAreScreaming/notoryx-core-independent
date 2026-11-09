/// Messages written now to go out later. They send while the app is running
/// and connected to the radio they were written for.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_send.dart';
import 'connection.dart';
import 'safety.dart';

const scheduledMessagesSetting = 'scheduled_messages';

/// A message more than this late is held back, because it may no longer be
/// true. It stays listed as missed.
const scheduledGrace = Duration(hours: 1);

final class ScheduledMessage {
  const ScheduledMessage({
    required this.id,
    required this.radioKey,
    required this.thread,
    required this.title,
    required this.text,
    required this.at,
  });

  factory ScheduledMessage.fromJson(Map<String, Object?> json) =>
      ScheduledMessage(
        id: json['id']! as int,
        radioKey: json['radio']! as String,
        thread: json['thread']! as String,
        title: json['title']! as String,
        text: json['text']! as String,
        at: DateTime.fromMillisecondsSinceEpoch(json['at']! as int),
      );

  final int id;
  final String radioKey;
  final String thread;
  final String title;
  final String text;
  final DateTime at;

  bool isDue(DateTime now) => !at.isAfter(now);

  bool isMissed(DateTime now) => now.difference(at) > scheduledGrace;

  Map<String, Object?> toJson() => {
    'id': id,
    'radio': radioKey,
    'thread': thread,
    'title': title,
    'text': text,
    'at': at.millisecondsSinceEpoch,
  };
}

/// The messages waiting to go out, soonest first.
class ScheduledMessages extends AsyncNotifier<List<ScheduledMessage>> {
  bool _sending = false;

  @override
  Future<List<ScheduledMessage>> build() async {
    final raw = await ref.read(storeProvider).setting(scheduledMessagesSetting);
    if (raw == null) return const [];
    return [
      for (final item in jsonDecode(raw) as List<Object?>)
        ScheduledMessage.fromJson(item! as Map<String, Object?>),
    ]..sort((a, b) => a.at.compareTo(b.at));
  }

  Future<void> _save(List<ScheduledMessage> list) async {
    final sorted = [...list]..sort((a, b) => a.at.compareTo(b.at));
    await ref
        .read(storeProvider)
        .saveSetting(
          scheduledMessagesSetting,
          jsonEncode([for (final m in sorted) m.toJson()]),
        );
    state = AsyncData(sorted);
  }

  Future<void> add({
    required String radioKey,
    required String thread,
    required String title,
    required String text,
    required DateTime at,
  }) async {
    final list = await future;
    await _save([
      ...list,
      ScheduledMessage(
        id: ref.read(safetyClockProvider)().microsecondsSinceEpoch,
        radioKey: radioKey,
        thread: thread,
        title: title,
        text: text,
        at: at,
      ),
    ]);
  }

  Future<void> remove(int id) async {
    final list = await future;
    await _save([
      for (final m in list)
        if (m.id != id) m,
    ]);
  }

  /// Sends everything due for the connected radio.
  Future<void> sendDue() async {
    if (_sending) return;
    _sending = true;
    try {
      final now = ref.read(safetyClockProvider)();
      for (final m in await future) {
        final connection = ref.read(connectionProvider);
        if (connection is! Connected) return;
        if (m.radioKey != connection.radio.key ||
            !m.isDue(now) ||
            m.isMissed(now)) {
          continue;
        }
        // Taken off first, so it can never go out twice. If the radio
        // refuses, the chat shows it as failed with Send again.
        await remove(m.id);
        try {
          await sendToThread(
            connection,
            ref.read(storeProvider),
            m.thread,
            m.text,
          );
        } on Object catch (e) {
          ref.read(connectionLogProvider).add('scheduled message: $e');
        }
      }
    } finally {
      _sending = false;
    }
  }
}

final scheduledMessagesProvider =
    AsyncNotifierProvider<ScheduledMessages, List<ScheduledMessage>>(
      ScheduledMessages.new,
    );

/// Checks for due messages while a radio is connected.
final scheduledSenderProvider = Provider<void>((ref) {
  if (ref.watch(connectionProvider) is! Connected) return;
  void check() =>
      unawaited(ref.read(scheduledMessagesProvider.notifier).sendDue());
  final timer = Timer.periodic(const Duration(seconds: 15), (_) => check());
  ref.onDispose(timer.cancel);
  check();
});
