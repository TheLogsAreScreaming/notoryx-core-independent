import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';

/// Setting holding the quick messages as a JSON list of strings.
const quickMessagesSetting = 'quick_messages';

/// What the list starts with, and what "Reset" brings back.
const defaultQuickMessages = [
  'OK',
  'On my way',
  'Arrived safe',
  'Running late',
  'Where are you?',
  'All good here',
  'Need help',
];

/// Short replies sent with one tap from any chat, in the person's order.
final quickMessagesProvider =
    AsyncNotifierProvider<QuickMessages, List<String>>(QuickMessages.new);

class QuickMessages extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final raw = await ref.read(storeProvider).setting(quickMessagesSetting);
    if (raw == null) return defaultQuickMessages;
    try {
      return [
        for (final item in jsonDecode(raw) as List<Object?>)
          if (item is String && item.trim().isNotEmpty) item,
      ];
    } on FormatException {
      return defaultQuickMessages;
    } on TypeError {
      return defaultQuickMessages;
    }
  }

  List<String> get _current => state.value ?? defaultQuickMessages;

  Future<void> _save(List<String> next) async {
    state = AsyncData(List.unmodifiable(next));
    await ref
        .read(storeProvider)
        .saveSetting(quickMessagesSetting, jsonEncode(next));
  }

  /// Adds [text] at the end, unless it's blank or already there.
  Future<void> add(String text) async {
    final t = text.trim();
    if (t.isEmpty || _current.contains(t)) return;
    await _save([..._current, t]);
  }

  /// Replaces the message at [index] with [text]; blank removes it.
  Future<void> edit(int index, String text) async {
    final t = text.trim();
    final next = [..._current];
    if (t.isEmpty) {
      next.removeAt(index);
    } else {
      next[index] = t;
    }
    await _save(next);
  }

  Future<void> remove(int index) => _save([..._current]..removeAt(index));

  /// Moves the message at [oldIndex] so it ends up at [newIndex].
  Future<void> move(int oldIndex, int newIndex) {
    final next = [..._current];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), item);
    return _save(next);
  }

  Future<void> reset() => _save(defaultQuickMessages);
}

/// Unsent text left in each chat's box, by thread.
final draftsProvider = StreamProvider.family<Map<String, String>, String>(
  (ref, radioKey) => ref.watch(storeProvider).watchDrafts(radioKey),
);
