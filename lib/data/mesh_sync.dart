import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../radio/radio.dart';
import 'database.dart';
import 'mesh_store.dart';

/// How hard to try before a direct message counts as failed.
final class RetryPolicy {
  const RetryPolicy({
    this.directAttempts = 4,
    this.floodAttempts = 4,
    this.minWait = const Duration(seconds: 5),
    this.extraWait = const Duration(seconds: 2),
  });

  /// Sends along the contact's known route before giving up on it.
  final int directAttempts;

  /// Sends by flood after the route is dropped (or when there is none).
  final int floodAttempts;

  /// Shortest wait for an ack, whatever the radio estimates.
  final Duration minWait;

  /// Added to the radio's own estimate, for slow repeaters.
  final Duration extraWait;
}

/// Most text the firmware takes in one direct message, in UTF-8 bytes.
const maxDirectTextBytes = 160;

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
    this.retry = const RetryPolicy(),
  });

  final RadioSession _session;
  final MeshStore _store;
  final String appName;

  /// Adverts arrive in bursts; contact refreshes wait this long to batch them.
  final Duration contactRefreshDelay;

  final RetryPolicy retry;

  /// Direct messages still being tried, by message id.
  final _outbox = <int, _DirectSend>{};

  /// Every ack code handed out, to the message it belongs to. Each attempt
  /// has its own code and an ack for an earlier one can still arrive.
  final _ackOwner = <int, int>{};

  final _retryingChanges = StreamController<Set<int>>.broadcast();

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

  /// Ids of direct messages that are still being tried.
  Set<int> get retrying => Set.unmodifiable(_outbox.keys);

  /// Emits [retrying] whenever it changes.
  Stream<Set<int>> get retryingChanges => _retryingChanges.stream;

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
    await _store.failStalePending(key);
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

  /// Changes the radio's LoRa settings, then reads them back so [radio]
  /// shows what the radio really uses. Throws if the radio refuses them.
  Future<ConnectedRadio> setRadioParams(SetRadioParams params) async {
    final current = _radio;
    if (current == null) throw StateError('The sync has not started.');
    await _session.run(params);
    final self = await _session.request<SelfInfo>(AppStart(appName: appName));
    return _radio = (key: current.key, self: self, device: current.device);
  }

  /// Sends a direct message and stores it. Returns the message id once the
  /// radio has accepted the first attempt; throws if it refuses.
  ///
  /// Until an ack arrives the message is resent: up to
  /// [RetryPolicy.directAttempts] times along the known route, then the route
  /// is dropped and it floods up to [RetryPolicy.floodAttempts] times. With
  /// no ack after that it is marked failed. [stopTrying] gives up early and
  /// [resend] starts again.
  Future<int> sendDirect(PublicKey to, String text, {DateTime? now}) async {
    final key = _requireKey();
    _checkDirectText(text);
    final job = _DirectSend(to: to, text: text, sentAt: _seconds(now));
    // Encode first so a message too long for the radio is refused before
    // anything is stored.
    job.command().encode();
    job.id = await _store.saveOutgoing(
      key,
      thread: Threads.direct(to.hex),
      body: text,
      sentAt: job.sentAt,
    );
    await _begin(job);
    return job.id;
  }

  /// Sends a failed message again: a direct message gets a fresh round of
  /// attempts, a channel message one more send. The receiver drops copies it
  /// already has, so a resend never shows up twice.
  Future<void> resend(int id) async {
    final key = _requireKey();
    final message = await _store.message(id);
    if (message == null ||
        !message.outgoing ||
        message.radioKey != key ||
        message.status != MessageStatus.failed) {
      return;
    }
    await _store.markPending(id);
    final target = message.thread.substring(2);
    if (message.kind == MessageKind.channel) {
      try {
        await _session.run(
          SendChannelText(
            channel: int.parse(target),
            text: message.body,
            timestamp: message.sentAt,
          ),
        );
        await _store.markSent(id);
      } on RadioRequestException {
        await _store.markFailed(id);
        rethrow;
      }
      return;
    }
    final job = _DirectSend(
      to: PublicKey.fromHex(target),
      text: message.body,
      sentAt: message.sentAt,
      // Keep counting so each packet differs from earlier tries; repeaters
      // drop packets they have already passed on.
      attempt: message.attempts,
    )..id = id;
    await _begin(job);
  }

  /// Stops resending [id] and marks it failed.
  Future<void> stopTrying(int id) async {
    final job = _outbox.remove(id);
    if (job == null) return;
    job.timer?.cancel();
    _notifyRetrying();
    await _store.markFailed(id);
  }

  Future<void> _begin(_DirectSend job) async {
    _outbox[job.id] = job;
    _notifyRetrying();
    try {
      await _transmit(job);
    } on RadioRequestException {
      await _fail(job);
      rethrow;
    }
  }

  Future<void> _transmit(_DirectSend job) async {
    final sent = await _session.request<SentReply>(job.command());
    _ackOwner[sent.ackCode] = job.id;
    job
      ..attempt += 1
      ..lastFlooded = sent.flooded;
    if (sent.flooded) {
      job.floods += 1;
    } else {
      job.directs += 1;
    }
    await _store.markSent(
      job.id,
      ackCode: sent.ackCode,
      flooded: sent.flooded,
      attempts: job.attempt,
    );
    if (!_outbox.containsKey(job.id)) return; // acked or stopped meanwhile
    final wait = Duration(
      milliseconds: math.max(retry.minWait.inMilliseconds, sent.timeoutMs),
    );
    job.timer = Timer(wait + retry.extraWait, () {
      _work = _work.then((_) => _onNoAck(job)).catchError(_errors.add);
    });
  }

  Future<void> _onNoAck(_DirectSend job) async {
    if (_outbox[job.id] != job) return;
    final directLeft = !job.lastFlooded && job.directs < retry.directAttempts;
    final floodLeft = job.floods < retry.floodAttempts;
    if (!directLeft && !floodLeft) return _fail(job);
    if (!directLeft && !job.lastFlooded) {
      // The route isn't working; drop it so the radio floods instead.
      try {
        await _session.run(ResetPath(job.to));
      } on RadioRequestException catch (e) {
        _errors.add(e);
      }
    }
    try {
      await _transmit(job);
    } on RadioRequestException {
      await _fail(job);
    }
  }

  Future<void> _fail(_DirectSend job) async {
    job.timer?.cancel();
    if (_outbox[job.id] == job) {
      _outbox.remove(job.id);
      _notifyRetrying();
    }
    await _store.markFailed(job.id);
  }

  Future<void> _delivered(String key, int ackCode) async {
    final id = _ackOwner[ackCode];
    if (id == null) {
      await _store.markDelivered(key, ackCode);
      return;
    }
    final job = _outbox.remove(id);
    if (job != null) {
      job.timer?.cancel();
      _notifyRetrying();
    }
    await _store.markDeliveredById(id);
  }

  void _notifyRetrying() {
    if (!_retryingChanges.isClosed) _retryingChanges.add(retrying);
  }

  static void _checkDirectText(String text) {
    if (utf8.encode(text).length > maxDirectTextBytes) {
      throw ArgumentError.value(
        text,
        'text',
        'longer than $maxDirectTextBytes bytes',
      );
    }
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

  /// Stops syncing. Direct messages still waiting for an ack are marked
  /// failed, since no ack can arrive without the radio.
  Future<void> stop() async {
    _contactRefresh?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _work;
    final waiting = _outbox.values.toList();
    for (final job in waiting) {
      await _fail(job);
    }
    await _retryingChanges.close();
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
        await _delivered(key, ackCode);
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

/// A direct message on its way: what was sent, and how often.
final class _DirectSend {
  _DirectSend({
    required this.to,
    required this.text,
    required this.sentAt,
    this.attempt = 0,
  });

  final PublicKey to;
  final String text;
  final int sentAt;
  late int id;

  /// Attempts sent so far, counting earlier rounds for a resend.
  int attempt;
  int directs = 0;
  int floods = 0;
  bool lastFlooded = false;
  Timer? timer;

  SendTextMessage command() => SendTextMessage(
    recipient: to,
    text: text,
    timestamp: sentAt,
    attempt: _attemptByte(),
  );

  // The firmware carries attempts above 3 in two extra payload bytes, which
  // a message at the length limit doesn't have room for.
  int _attemptByte() {
    final fits = utf8.encode(text).length <= maxDirectTextBytes - 2;
    return fits ? attempt % 256 : attempt % 4;
  }
}
