import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import 'radio_connector.dart';

/// Where the app is with its radio.
sealed class RadioConnectionState {
  const RadioConnectionState();
}

final class Disconnected extends RadioConnectionState {
  const Disconnected({this.error});

  /// Why the last attempt or connection ended, if it wasn't the user.
  final String? error;
}

/// A first connection the person asked for.
final class Connecting extends RadioConnectionState {
  const Connecting(this.target);

  final RadioTarget target;
}

final class Connected extends RadioConnectionState {
  const Connected({
    required this.radio,
    required this.sync,
    required this.target,
  });

  final ConnectedRadio radio;
  final MeshSync sync;
  final RadioTarget target;
}

/// Getting the last radio back: at launch, or after the link dropped. Chats
/// stay readable from storage meanwhile.
final class Reconnecting extends RadioConnectionState {
  const Reconnecting({
    required this.target,
    required this.radioKey,
    required this.radioName,
    this.attempt = 0,
    this.error,
  });

  final RadioTarget target;
  final String radioKey;
  final String radioName;

  /// Failed tries so far.
  final int attempt;

  /// Why the last try failed.
  final String? error;
}

final databaseProvider = Provider<MeshDatabase>((ref) {
  final db = MeshDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final storeProvider = Provider<MeshStore>(
  (ref) => MeshStore(ref.watch(databaseProvider)),
);

final radioConnectorProvider = Provider<RadioConnector>(
  (ref) => const DeviceRadioConnector(),
);

/// Waits between reconnect tries; the last one repeats until it works.
final reconnectDelaysProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ],
);

final connectionProvider =
    NotifierProvider<ConnectionController, RadioConnectionState>(
      ConnectionController.new,
    );

/// Opens, syncs and closes the one radio connection, and gets it back on
/// its own: at launch it reconnects to the last radio, and when the link
/// drops it keeps trying with growing waits. Disconnecting on purpose stops
/// both until the person connects again.
class ConnectionController extends Notifier<RadioConnectionState> {
  /// Setting that holds the last radio, as JSON.
  static const lastRadioSetting = 'last_radio';

  RadioLink? _link;
  RadioSession? _session;
  MeshSync? _sync;
  Timer? _retry;

  /// The radio last connected this run, for saving the reconnect setting.
  String? _lastKey;
  String? _lastName;

  /// Bumped whenever the person takes over, so a reconnect in flight knows
  /// its result is no longer wanted.
  int _generation = 0;

  @override
  RadioConnectionState build() {
    ref.onDispose(() {
      _retry?.cancel();
      _generation++;
      _teardown();
    });
    Future.microtask(_resumeLastRadio);
    return const Disconnected();
  }

  Future<void> connect(RadioTarget target) async {
    if (state is Connecting || state is Connected) return;
    _retry?.cancel();
    final generation = ++_generation;
    await _teardown();
    state = Connecting(target);
    try {
      await _open(target, generation);
    } on Object catch (error) {
      await _teardown();
      if (ref.mounted && generation == _generation) {
        state = Disconnected(error: _describe(error));
      }
    }
  }

  /// Disconnects and stays disconnected, including after a restart.
  Future<void> disconnect() async {
    _retry?.cancel();
    _generation++;
    await _teardown();
    await _saveLast(autoConnect: false);
    if (ref.mounted) state = const Disconnected();
  }

  /// Skips the wait before the next reconnect try.
  void retryNow() {
    final current = state;
    if (current is! Reconnecting) return;
    _retry?.cancel();
    _tryReconnect(current, _generation);
  }

  /// Changes the connected radio's LoRa settings. Throws when there is no
  /// radio or it refuses the settings.
  Future<void> setRadioParams(SetRadioParams params) async {
    final current = state;
    if (current is! Connected) throw StateError('No radio is connected.');
    final radio = await current.sync.setRadioParams(params);
    if (ref.mounted && state == current) {
      state = Connected(
        radio: radio,
        sync: current.sync,
        target: current.target,
      );
    }
  }

  Future<void> _resumeLastRadio() async {
    final saved = await _loadLast();
    if (saved == null || !saved.autoConnect || !ref.mounted) return;
    if (state is! Disconnected) return;
    final reconnecting = Reconnecting(
      target: saved.target,
      radioKey: saved.radioKey,
      radioName: saved.radioName,
    );
    state = reconnecting;
    _tryReconnect(reconnecting, _generation);
  }

  Future<void> _open(RadioTarget target, int generation) async {
    final link = _link = await ref.read(radioConnectorProvider).open(target);
    final session = _session = RadioSession(link);
    final sync = _sync = MeshSync(session, ref.read(storeProvider));
    final radio = await sync.start();
    if (!ref.mounted || generation != _generation) {
      await _teardown();
      return;
    }
    state = Connected(radio: radio, sync: sync, target: target);
    _lastName = radio.self.name;
    _lastKey = radio.key;
    await _saveLast(autoConnect: true, target: target);
    unawaited(link.done.then((_) => _onLinkDropped(link, target)));
  }

  Future<void> _onLinkDropped(RadioLink link, RadioTarget target) async {
    if (!ref.mounted || link != _link) return; // already replaced or closed
    final current = state;
    if (current is! Connected) return;
    await _teardown();
    final reconnecting = Reconnecting(
      target: target,
      radioKey: current.radio.key,
      radioName: current.radio.self.name,
      error: 'The radio disconnected.',
    );
    state = reconnecting;
    _schedule(reconnecting, _generation);
  }

  void _schedule(Reconnecting from, int generation) {
    final delays = ref.read(reconnectDelaysProvider);
    final wait = delays[from.attempt.clamp(0, delays.length - 1)];
    _retry?.cancel();
    _retry = Timer(wait, () => _tryReconnect(from, generation));
  }

  Future<void> _tryReconnect(Reconnecting from, int generation) async {
    if (!ref.mounted || generation != _generation) return;
    try {
      await _open(from.target, generation);
    } on Object catch (error) {
      await _teardown();
      if (!ref.mounted || generation != _generation) return;
      final next = Reconnecting(
        target: from.target,
        radioKey: from.radioKey,
        radioName: from.radioName,
        attempt: from.attempt + 1,
        error: _describe(error),
      );
      state = next;
      _schedule(next, generation);
    }
  }

  Future<void> _teardown() async {
    final sync = _sync, session = _session, link = _link;
    _sync = null;
    _session = null;
    _link = null;
    await sync?.stop();
    await session?.close();
    await link?.close();
  }

  Future<void> _saveLast({
    required bool autoConnect,
    RadioTarget? target,
  }) async {
    final store = ref.read(storeProvider);
    final saved = target == null ? await _loadLast() : null;
    final chosen = target ?? saved?.target;
    final key = _lastKey ?? saved?.radioKey;
    final name = _lastName ?? saved?.radioName;
    if (chosen == null || key == null || name == null) return;
    await store.saveSetting(
      lastRadioSetting,
      jsonEncode({
        'target': chosen.toJson(),
        'radioKey': key,
        'radioName': name,
        'autoConnect': autoConnect,
      }),
    );
  }

  Future<_SavedRadio?> _loadLast() async {
    final raw = await ref.read(storeProvider).setting(lastRadioSetting);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final target = RadioTarget.fromJson(
        (json['target']! as Map).cast<String, Object?>(),
      );
      if (target == null) return null;
      return (
        target: target,
        radioKey: json['radioKey']! as String,
        radioName: json['radioName']! as String,
        autoConnect: json['autoConnect'] == true,
      );
    } on Object {
      return null; // an unreadable setting just means no auto-connect
    }
  }

  static String _describe(Object error) => switch (error) {
    BluetoothUnavailable() => error.message,
    RadioTimeout() => 'The radio did not answer.',
    RadioDisconnected() ||
    LinkClosedException() => 'The connection closed before setup finished.',
    _ => 'Could not connect: $error',
  };
}

typedef _SavedRadio = ({
  RadioTarget target,
  String radioKey,
  String radioName,
  bool autoConnect,
});

/// The radio whose chats are showing: the connected one, or the one being
/// reconnected. Null when there is none.
final radioKeyProvider = Provider<String?>(
  (ref) => switch (ref.watch(connectionProvider)) {
    Connected(:final radio) => radio.key,
    Reconnecting(:final radioKey) => radioKey,
    _ => null,
  },
);

final contactsProvider = StreamProvider.family<List<Contact>, String>(
  (ref, radioKey) => ref.watch(storeProvider).watchContacts(radioKey),
);

final channelsProvider = StreamProvider.family<List<Channel>, String>(
  (ref, radioKey) => ref.watch(storeProvider).watchChannels(radioKey),
);

final conversationsProvider = StreamProvider.family<List<Message>, String>(
  (ref, radioKey) => ref.watch(storeProvider).watchConversations(radioKey),
);

final threadProvider =
    StreamProvider.family<List<Message>, ({String radioKey, String thread})>(
      (ref, id) => ref.watch(storeProvider).watchThread(id.radioKey, id.thread),
    );

/// Ids of direct messages still being resent.
final retryingProvider = StreamProvider<Set<int>>((ref) async* {
  final state = ref.watch(connectionProvider);
  if (state is! Connected) {
    yield const {};
    return;
  }
  yield state.sync.retrying;
  yield* state.sync.retryingChanges;
});
