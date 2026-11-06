import 'dart:async';
import 'dart:convert';

import '../data/data.dart';

/// A short record of what the connection did, kept across restarts so a
/// problem at launch can be read afterwards. Shown on the Connection log
/// screen, where it can be copied.
class ConnectionLog {
  ConnectionLog(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const setting = 'connection_log';
  static const maxEntries = 300;

  final MeshStore _store;
  final DateTime Function() _clock;
  final _entries = <String>[];
  final _changes = StreamController<List<String>>.broadcast();
  Future<void>? _loaded;
  Timer? _save;

  /// Oldest first.
  List<String> get entries => List.unmodifiable(_entries);

  Stream<List<String>> get changes => _changes.stream;

  /// Reads what earlier runs recorded. Safe to call more than once.
  Future<void> load() => _loaded ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _store.setting(setting);
      if (raw == null) return;
      final earlier = (jsonDecode(raw) as List).cast<String>();
      _entries.insertAll(0, earlier);
      _trim();
      _changes.add(entries);
    } on Object {
      // A damaged log is just started again.
    }
  }

  void add(String message) {
    final t = _clock().toLocal().toIso8601String().substring(0, 19);
    _entries.add('$t  $message');
    _trim();
    if (!_changes.isClosed) _changes.add(entries);
    // Write at most once a second; launch problems need the log on disk.
    _save ??= Timer(const Duration(seconds: 1), _flush);
  }

  Future<void> _flush() async {
    _save = null;
    try {
      await _store.saveSetting(setting, jsonEncode(_entries));
    } on Object {
      // The log must never break the connection.
    }
  }

  Future<void> clear() async {
    _entries.clear();
    _changes.add(entries);
    await _store.removeSetting(setting);
  }

  void _trim() {
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  Future<void> dispose() async {
    if (_save != null) {
      _save!.cancel();
      await _flush();
    }
    await _changes.close();
  }
}
