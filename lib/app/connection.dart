import 'dart:async';

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

final class Connecting extends RadioConnectionState {
  const Connecting(this.target);

  final RadioTarget target;
}

final class Connected extends RadioConnectionState {
  const Connected({required this.radio, required this.sync});

  final ConnectedRadio radio;
  final MeshSync sync;
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

final connectionProvider =
    NotifierProvider<ConnectionController, RadioConnectionState>(
      ConnectionController.new,
    );

/// Opens, syncs and closes the one radio connection.
class ConnectionController extends Notifier<RadioConnectionState> {
  RadioLink? _link;
  RadioSession? _session;
  MeshSync? _sync;

  @override
  RadioConnectionState build() {
    ref.onDispose(_teardown);
    return const Disconnected();
  }

  Future<void> connect(RadioTarget target) async {
    if (state is! Disconnected) return;
    state = Connecting(target);
    try {
      final link = _link = await ref.read(radioConnectorProvider).open(target);
      final session = _session = RadioSession(link);
      final sync = _sync = MeshSync(session, ref.read(storeProvider));
      final radio = await sync.start();
      if (!ref.mounted) return;
      state = Connected(radio: radio, sync: sync);
      unawaited(
        link.done.then((_) {
          if (ref.mounted && state is Connected) {
            _teardown();
            state = const Disconnected(error: 'The radio disconnected.');
          }
        }),
      );
    } on Object catch (error) {
      await _teardown();
      if (ref.mounted) state = Disconnected(error: _describe(error));
    }
  }

  Future<void> disconnect() async {
    await _teardown();
    if (ref.mounted) state = const Disconnected();
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

  static String _describe(Object error) => switch (error) {
    RadioTimeout() => 'The radio did not answer.',
    RadioDisconnected() ||
    LinkClosedException() => 'The connection closed before setup finished.',
    _ => 'Could not connect: $error',
  };
}

/// The connected radio's key, or null when disconnected.
final radioKeyProvider = Provider<String?>((ref) {
  final state = ref.watch(connectionProvider);
  return state is Connected ? state.radio.key : null;
});

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
