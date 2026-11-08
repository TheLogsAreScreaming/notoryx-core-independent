/// Blocking senders and noticing mentions.
///
/// Blocked messages are still stored, so unblocking brings them back; they
/// are just left out of chats, unread counts and notifications. On a
/// channel a sender is only known by the name they post under, so that is
/// what is blocked there. Direct senders are blocked by key.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'connection.dart';

/// Who is blocked.
final class BlockList {
  const BlockList({this.names = const {}, this.keys = const {}});

  /// Channel senders, by the name they post under.
  final Set<String> names;

  /// Direct senders, by public key (hex).
  final Set<String> keys;

  bool get isEmpty => names.isEmpty && keys.isEmpty;

  /// Whether [m] came from someone blocked. Your own messages never do.
  bool blocks(Message m) {
    if (m.outgoing) return false;
    return switch (m.kind) {
      MessageKind.channel => names.contains(m.senderName),
      MessageKind.direct => keys.contains(m.thread.substring(2)),
    };
  }
}

Set<String> _decode(String? raw) {
  if (raw == null) return const {};
  try {
    return {
      for (final v in jsonDecode(raw) as List<Object?>)
        if (v is String) v,
    };
  } on Object {
    return const {};
  }
}

/// The block list as stored now.
Future<BlockList> readBlockList(MeshStore store) async => BlockList(
  names: _decode(await store.setting(MeshStore.blockedNamesSetting)),
  keys: _decode(await store.setting(MeshStore.blockedKeysSetting)),
);

final blockListProvider = StreamProvider<BlockList>(
  (ref) => ref
      .watch(storeProvider)
      .watchSettingsWithPrefix('blocked_')
      .map(
        (s) => BlockList(names: _decode(s['names']), keys: _decode(s['keys'])),
      ),
);

final blockingProvider = Provider<Blocking>(Blocking.new);

class Blocking {
  Blocking(this._ref);

  final Ref _ref;

  MeshStore get _store => _ref.read(storeProvider);

  Future<Set<String>> _read(String key) async => {
    ..._decode(await _store.setting(key)),
  };

  Future<void> _write(String key, Set<String> values) => values.isEmpty
      ? _store.removeSetting(key)
      : _store.saveSetting(key, jsonEncode(values.toList()..sort()));

  Future<void> blockName(String name) async => _write(
    MeshStore.blockedNamesSetting,
    {...await _read(MeshStore.blockedNamesSetting), name},
  );

  Future<void> unblockName(String name) async => _write(
    MeshStore.blockedNamesSetting,
    (await _read(MeshStore.blockedNamesSetting))..remove(name),
  );

  Future<void> blockKey(String key) async => _write(
    MeshStore.blockedKeysSetting,
    {...await _read(MeshStore.blockedKeysSetting), key},
  );

  Future<void> unblockKey(String key) async => _write(
    MeshStore.blockedKeysSetting,
    (await _read(MeshStore.blockedKeysSetting))..remove(key),
  );
}

/// Whether [body] mentions [myName], as `@[Name]` or `@Name`, ignoring case.
bool mentions(String body, String? myName) {
  final name = myName?.trim().toLowerCase();
  if (name == null || name.isEmpty) return false;
  final text = body.toLowerCase();
  return text.contains('@[$name]') ||
      RegExp(
        '@${RegExp.escape(name)}(?![\\p{L}\\p{N}])',
        unicode: true,
      ).hasMatch(text);
}
