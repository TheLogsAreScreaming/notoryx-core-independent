import 'dart:async';

import '../radio/radio.dart';
import 'mesh_store.dart';

/// What the app knows once a radio is connected and synced.
typedef ConnectedRadio = ({String key, SelfInfo self, DeviceInfo device});

/// Keeps the [MeshStore] in step with one connected radio. On [start] it
/// downloads contacts, channels and queued messages; afterwards it saves
/// incoming messages, applies contact pushes and records delivery acks.
/// Sending goes through here too, so every message is stored with its status.
class MeshSync {
  MeshSync(
    this._session,
    this._store, {
    this.appName = 'NOTORYX Core',
    this.contactRefreshDelay = const Duration(seconds: 2),
  });

  final RadioSession _session;
  final MeshStore _store;
  final String appName;

  /// Adverts arrive in bursts; contact refreshes wait this long to batch them.
  final Duration contactRefreshDelay;

  final _subscriptions = <StreamSubscription<Object>>[];
  final _early = <Object>[];
  ConnectedRadio? _radio;
  Timer? _contactRefresh;
  Future<void> _work = Future.value();

  final _errors = StreamController<Object>.broadcast();

  ConnectedRadio? get radio => _radio;

  /// Background sync work that failed, such as a contact refresh that timed
  /// out. Sending reports its own errors to the caller instead.
  Stream<Object> get errors => _errors.stream;

  /// Opens the session and brings the store up to date.
  Future<ConnectedRadio> start({DateTime? now}) async {
    // Listen before anything is sent: the radio may push as soon as the
    // session opens. Events before the radio key is known are held.
    _subscriptions
      ..add(_session.messages.listen((m) => _handle(m)))
      ..add(_session.pushes.listen((p) => _handle(p)));

    final started = await _session.start(appName: appName, now: now);
    final key = started.self.publicKey.hex;
    await _store.rememberRadio(started.self);
    _radio = (key: key, self: started.self, device: started.device);

    await _syncContacts();
    final slots = started.device.maxChannels ?? 8;
    await _store.saveChannels(key, await _session.fetchChannels(slots));

    for (final event in List.of(_early)) {
      _handle(event);
    }
    _early.clear();
    await _session.syncMessages();
    await _work;
    return _radio!;
  }

  /// Sends a direct message and stores it. Returns the message id. The
  /// stored status moves to sent when the radio accepts it, delivered when
  /// the ack arrives, or failed if the radio refuses.
  Future<int> sendDirect(PublicKey to, String text, {DateTime? now}) {
    final sentAt = _seconds(now);
    final command = SendTextMessage(
      recipient: to,
      text: text,
      timestamp: sentAt,
    );
    return _send(Threads.direct(to.hex), text, sentAt, command, (id) async {
      final sent = await _session.request<SentReply>(command);
      await _store.markSent(id, ackCode: sent.ackCode, flooded: sent.flooded);
    });
  }

  /// Sends to a channel slot and stores it. Channel messages have no ack, so
  /// they end at sent.
  Future<int> sendChannel(int slot, String text, {DateTime? now}) {
    final sentAt = _seconds(now);
    final command = SendChannelText(
      channel: slot,
      text: text,
      timestamp: sentAt,
    );
    return _send(Threads.channel(slot), text, sentAt, command, (id) async {
      await _session.run(command);
      await _store.markSent(id);
    });
  }

  Future<void> stop() async {
    _contactRefresh?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _work;
    await _errors.close();
  }

  Future<int> _send(
    String thread,
    String text,
    int sentAt,
    RadioCommand command,
    Future<void> Function(int id) transmit,
  ) async {
    final key = _requireKey();
    // Encode first so a message too long for the radio is refused before
    // anything is stored.
    command.encode();
    final id = await _store.saveOutgoing(
      key,
      thread: thread,
      body: text,
      sentAt: sentAt,
    );
    try {
      await transmit(id);
    } on RadioRequestException {
      await _store.markFailed(id);
      rethrow;
    }
    return id;
  }

  void _handle(Object event) {
    final key = _radio?.key;
    if (key == null) {
      _early.add(event);
      return;
    }
    // Store writes run one after another so acks never overtake the message
    // they confirm.
    _work = _work.then((_) => _apply(key, event)).catchError(_errors.add);
  }

  Future<void> _apply(String key, Object event) async {
    switch (event) {
      case ContactMessage() || ChannelMessage():
        await _store.saveIncoming(key, event as ReplyFrame);
      case NewAdvert(:final contact):
        await _store.saveContact(key, contact);
      case ContactDeleted(:final publicKey):
        await _store.removeContact(key, publicKey);
      case SendConfirmed(:final ackCode):
        await _store.markDelivered(key, ackCode);
      case AdvertHeard() || PathUpdated():
        _scheduleContactRefresh();
    }
  }

  void _scheduleContactRefresh() {
    _contactRefresh?.cancel();
    _contactRefresh = Timer(contactRefreshDelay, () {
      _work = _work.then((_) => _syncContacts()).catchError(_errors.add);
    });
  }

  Future<void> _syncContacts() async {
    final key = _requireKey();
    final since = (await _store.radio(key))?.contactsSince ?? 0;
    final sync = await _session.fetchContacts(since: since == 0 ? null : since);
    await _store.saveContacts(key, sync, since: since);
  }

  String _requireKey() {
    final key = _radio?.key;
    if (key == null) throw StateError('MeshSync.start() has not finished');
    return key;
  }

  static int _seconds(DateTime? now) =>
      (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
}
