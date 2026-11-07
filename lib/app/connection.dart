import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import 'connection_log.dart';
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

final connectionLogProvider = Provider<ConnectionLog>((ref) {
  final log = ConnectionLog(ref.watch(storeProvider));
  ref.onDispose(log.dispose);
  return log;
});

final radioConnectorProvider = Provider<RadioConnector>(
  (ref) => DeviceRadioConnector(log: ref.watch(connectionLogProvider).add),
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

  ConnectionLog get _log => ref.read(connectionLogProvider);

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

  @override
  set state(RadioConnectionState value) {
    if (value.runtimeType != super.state.runtimeType) {
      _log.add('state: ${_describeState(value)}');
    }
    super.state = value;
  }

  static String _describeState(RadioConnectionState s) => switch (s) {
    Disconnected(:final error) =>
      'disconnected${error == null ? '' : ' ($error)'}',
    Connecting(:final target) => 'connecting to ${target.label}',
    Connected(:final radio) => 'connected to ${radio.self.name}',
    Reconnecting(:final target) => 'reconnecting to ${target.label}',
  };

  Future<void> connect(RadioTarget target) async {
    if (state is Connecting || state is Connected) return;
    _log.add('connect tapped: ${target.label}');
    _retry?.cancel();
    final generation = ++_generation;
    await _teardown();
    state = Connecting(target);
    try {
      await _open(target, generation);
    } on Object catch (error) {
      _log.add('connect failed: $error');
      await _teardown();
      if (ref.mounted && generation == _generation) {
        state = Disconnected(error: _describe(error));
      }
    }
  }

  /// Disconnects and stays disconnected, including after a restart.
  Future<void> disconnect() async {
    _log.add('disconnect tapped');
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
    _log.add('try now tapped');
    _retry?.cancel();
    _tryReconnect(current, _generation);
  }

  /// Changes the connected radio's LoRa settings. Throws when there is no
  /// radio or it refuses the settings.
  Future<void> setRadioParams(SetRadioParams params) => changeRadio([params]);

  /// Sends settings changes to the connected radio and shows its settings as
  /// read back afterwards, also when a change is refused (which throws).
  Future<void> changeRadio(List<RadioCommand> commands) async {
    final current = state;
    if (current is! Connected) throw StateError('No radio is connected.');
    try {
      await current.sync.changeRadio(commands);
    } finally {
      final radio = current.sync.radio;
      if (radio != null && ref.mounted && state == current) {
        state = Connected(
          radio: radio,
          sync: current.sync,
          target: current.target,
        );
      }
    }
  }

  Future<void> _resumeLastRadio() async {
    _SavedRadio? saved;
    try {
      await _log.load();
      _log.add('app started');
      saved = await _loadLast();
    } on Object catch (error) {
      _log.add('could not read the last radio: $error');
      return;
    }
    if (saved == null) {
      _log.add('no last radio saved');
      return;
    }
    if (!saved.autoConnect) {
      _log.add('last radio ${saved.target.label}: auto-connect is off');
      return;
    }
    if (!ref.mounted || state is! Disconnected) return;
    final reconnecting = Reconnecting(
      target: saved.target,
      radioKey: saved.radioKey,
      radioName: saved.radioName,
    );
    state = reconnecting;
    _tryReconnect(reconnecting, _generation);
  }

  Future<void> _open(RadioTarget target, int generation) async {
    _log.add('opening ${target.label}');
    final link = _link = await ref.read(radioConnectorProvider).open(target);
    // Watch for the drop straight away, so one during setup isn't missed.
    unawaited(link.done.then((_) => _onLinkDropped(link, target)));
    final session = _session = RadioSession(link);
    final sync = _sync = MeshSync(session, ref.read(storeProvider));
    final radio = await sync.start();
    if (!ref.mounted || generation != _generation) {
      _log.add('connected, but no longer wanted; closing');
      await _teardown();
      return;
    }
    _lastName = radio.self.name;
    _lastKey = radio.key;
    state = Connected(radio: radio, sync: sync, target: target);
    try {
      await _saveLast(autoConnect: true, target: target);
    } on Object catch (error) {
      _log.add('could not save the last radio: $error');
    }
  }

  Future<void> _onLinkDropped(RadioLink link, RadioTarget target) async {
    if (!ref.mounted || link != _link) return; // already replaced or closed
    final current = state;
    _log.add('link dropped while ${_describeState(current)}');
    if (current is! Connected) return; // setup fails and retries on its own
    // Show it straight away; closing the old link can take a while.
    final reconnecting = Reconnecting(
      target: target,
      radioKey: current.radio.key,
      radioName: current.radio.self.name,
      error: 'The radio disconnected.',
    );
    state = reconnecting;
    final generation = _generation;
    try {
      await _teardown();
    } on Object catch (error) {
      _log.add('closing the old link failed: $error');
    }
    if (!ref.mounted || generation != _generation) return;
    _schedule(reconnecting, generation);
  }

  void _schedule(Reconnecting from, int generation) {
    final delays = ref.read(reconnectDelaysProvider);
    final wait = delays[from.attempt.clamp(0, delays.length - 1)];
    _log.add('next try in ${wait.inSeconds} s');
    _retry?.cancel();
    _retry = Timer(wait, () => _tryReconnect(from, generation));
  }

  Future<void> _tryReconnect(Reconnecting from, int generation) async {
    if (!ref.mounted || generation != _generation) return;
    try {
      await _open(from.target, generation);
    } on Object catch (error) {
      _log.add('reconnect failed: $error');
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

/// Unread incoming messages per thread.
final unreadCountsProvider = StreamProvider.family<Map<String, int>, String>(
  (ref, radioKey) => ref.watch(storeProvider).watchUnreadCounts(radioKey),
);

/// Threads that don't notify or count toward the Chats total.
final mutedThreadsProvider = StreamProvider.family<Set<String>, String>(
  (ref, radioKey) => ref.watch(storeProvider).watchMuted(radioKey),
);

/// The conversation on screen right now, if any. New messages there are
/// read as they arrive and don't notify.
final openThreadProvider = NotifierProvider<OpenThread, String?>(
  OpenThread.new,
);

class OpenThread extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String thread) => state = thread;

  /// Clears [thread] if it is still the open one.
  void close(String thread) {
    if (ref.mounted && state == thread) state = null;
  }
}

/// Nodes the radio heard but didn't add.
final discoveredProvider = StreamProvider.family<List<DiscoveredData>, String>(
  (ref, radioKey) => ref.watch(storeProvider).watchDiscovered(radioKey),
);
