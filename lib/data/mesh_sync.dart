import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../app/region_tag.dart';
import '../radio/protocol/mesh_photo.dart';
import '../radio/protocol/region_scope.dart';
import '../radio/protocol/signed_post.dart';
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

/// What a server lets you do after logging in (the firmware's ACL roles).
enum ServerRole {
  guest,
  readOnly,
  readWrite,
  admin;

  static ServerRole from(LoginSucceeded reply) {
    final acl = reply.aclPermissions;
    if (acl != null) return ServerRole.values[acl & 3];
    // Older servers only say whether you're an admin.
    return reply.isAdmin ? admin : readWrite;
  }

  String get label => switch (this) {
    guest => 'Guest',
    readOnly => 'Read only',
    readWrite => 'Member',
    admin => 'Admin',
  };
}

sealed class LoginResult {
  const LoginResult();
}

final class LoggedIn extends LoginResult {
  const LoggedIn(this.role);

  final ServerRole role;
}

/// The server answered that the login failed.
final class LoginRefused extends LoginResult {
  const LoginRefused();
}

/// No answer: usually a wrong password (servers stay silent then), or the
/// server is out of range.
final class LoginNoReply extends LoginResult {
  const LoginNoReply();
}

/// Every channel slot on the radio is in use.
final class ChannelsFull implements Exception {
  const ChannelsFull();

  @override
  String toString() => 'Every channel slot on the radio is in use.';
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
  /// Regions of posts heard on air, by `slot:timestamp`.
  final _heardRegions = <String, String>{};

  MeshSync(
    this._session,
    this._store, {
    this.appName = 'NOTORYX Core',
    this.contactRefreshDelay = const Duration(seconds: 2),
    this.retry = const RetryPolicy(),
    this.serverReplyFloor = const Duration(seconds: 10),
    this.selfTelemetryWait = const Duration(seconds: 5),
  });

  final RadioSession _session;
  final MeshStore _store;
  final String appName;

  /// Adverts arrive in bursts; contact refreshes wait this long to batch them.
  final Duration contactRefreshDelay;

  final RetryPolicy retry;

  /// Shortest wait for a repeater or room server to answer.
  final Duration serverReplyFloor;

  /// How long the connected radio gets to report its own readings.
  final Duration selfTelemetryWait;

  /// Direct messages still being tried, by message id.
  final _outbox = <int, _DirectSend>{};

  /// Every ack code handed out, to the message it belongs to. Each attempt
  /// has its own code and an ack for an earlier one can still arrive.
  final _ackOwner = <int, int>{};

  final _retryingChanges = StreamController<Set<int>>.broadcast();
  final _incoming = StreamController<Message>.broadcast();

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

  /// The radio session, for one-off exchanges like discover pings.
  RadioSession get session => _session;

  /// Messages from other people, as each one is stored for the first time.
  Stream<Message> get incoming => _incoming.stream;

  /// Every packet the radio hears over the air, for the packet log.
  Stream<RxLog> get heard =>
      _session.pushes.where((p) => p is RxLog).cast<RxLog>();

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
  Future<ConnectedRadio> setRadioParams(SetRadioParams params) =>
      changeRadio([params]);

  /// Sends settings changes in order, then reads the radio's settings back
  /// so [radio] shows what it really uses. Throws if the radio refuses one;
  /// changes before it have still been made.
  Future<ConnectedRadio> changeRadio(List<RadioCommand> commands) async {
    final current = _radio;
    if (current == null) throw StateError('The sync has not started.');
    try {
      for (final command in commands) {
        await _session.run(command);
      }
    } finally {
      final self = await _session.request<SelfInfo>(AppStart(appName: appName));
      _radio = (key: current.key, self: self, device: current.device);
    }
    return _radio!;
  }

  /// The radio's identity private key, for a backup. Throws
  /// [RadioFeatureDisabled] when the firmware was built without it.
  Future<Uint8List> exportIdentityKey() async =>
      (await _session.request<PrivateKeyReply>(const ExportPrivateKey())).key;

  /// The radio's auto-add rules, or null on firmware without them.
  Future<AutoAddConfig?> autoAddConfig() async {
    try {
      final reply = await _session.request<AutoAddConfigReply>(
        const GetAutoAddConfig(),
      );
      return AutoAddConfig(flags: reply.flags, maxHops: reply.maxHops);
    } on RadioRequestException {
      return null;
    }
  }

  /// Reads the radio's receiver figures and stores them. Null on firmware
  /// without stats.
  Future<RadioStats?> sampleRadioStats() async {
    final RadioStats stats;
    try {
      stats = await _session.request<RadioStats>(const GetRadioStats());
    } on RadioRequestException {
      return null;
    }
    await _store.saveRadioStats(_radio!.key, stats);
    return stats;
  }

  Future<BatteryAndStorage> batteryAndStorage() =>
      _session.request<BatteryAndStorage>(const GetBatteryAndStorage());

  /// Restarts the radio. The link drops and reconnecting takes over.
  /// Adds a contact from a raw advert packet, as shared by other apps.
  Future<void> importAdvert(List<int> advert) async {
    await _session.run(ImportContact(advert));
    await _syncContacts();
  }

  /// Runs [command] on the connected radio's own command line and returns
  /// what it said. Needs firmware 14 or later.
  Future<String> runRadioCommand(String command) async =>
      (await _session.request<CliReply>(RunCliCommand(command))).text;

  Future<void> reboot() => _session.sendOnly(const Reboot());

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

  // Channels

  /// Number of channel slots on the radio.
  int get channelSlots => _radio?.device.maxChannels ?? 8;

  /// Puts a channel in the first free slot and returns the slot. If a
  /// channel with the same key is already there, returns its slot instead.
  /// Throws [ChannelsFull] when every slot is taken.
  Future<int> addChannel(String name, List<int> secret) async {
    final key = _requireKey();
    final channels = await _store.watchChannels(key).first;
    for (final c in channels) {
      if (_sameBytes(c.secret, secret)) return c.slot;
    }
    final used = {for (final c in channels) c.slot};
    final slot = Iterable<int>.generate(channelSlots)
        .where((i) => !used.contains(i))
        .firstOrNull;
    if (slot == null) throw const ChannelsFull();
    await _writeChannel(slot, name, secret);
    return slot;
  }

  /// Renames the channel in [slot], keeping its key.
  Future<void> renameChannel(int slot, String name) async {
    final key = _requireKey();
    final channel = (await _store.watchChannels(key).first)
        .where((c) => c.slot == slot)
        .firstOrNull;
    if (channel == null) return;
    await _writeChannel(slot, name, channel.secret);
  }

  /// Empties [slot]. Its messages stay on this device.
  Future<void> leaveChannel(int slot) => _writeChannel(slot, '', Uint8List(16));

  Future<void> _writeChannel(int slot, String name, List<int> secret) async {
    final key = _requireKey();
    await _session.run(SetChannel(index: slot, name: name, secret: secret));
    await _store.saveChannels(key, await _session.fetchChannels(channelSlots));
  }

  // Contacts

  /// Adds a node to the radio's contacts, for example from a shared link or
  /// from "heard nearby".
  Future<void> addContact({
    required PublicKey publicKey,
    required String name,
    required NodeType type,
    double? latitude,
    double? longitude,
    int lastAdvert = 0,
  }) async {
    final key = _requireKey();
    await _session.run(
      AddOrUpdateContact(
        RadioContact(
          publicKey: publicKey,
          type: type,
          flags: 0,
          outPathLength: pathUnknown,
          outPath: const [],
          name: name,
          lastAdvert: lastAdvert,
          latitude: latitude,
          longitude: longitude,
          lastModified: _seconds(null),
        ),
      ),
    );
    await _store.removeDiscovered(key, publicKey.hex);
    await _syncContacts();
  }

  Future<void> removeContact(PublicKey publicKey) async {
    final key = _requireKey();
    await _session.run(RemoveContact(publicKey));
    await _store.removeContact(key, publicKey);
  }

  /// Marks a contact as a favourite (or not), on the radio.
  Future<void> setFavourite(PublicKey publicKey, bool favourite) async {
    final key = _requireKey();
    final row = await _store.contact(key, publicKey.hex);
    if (row == null) return;
    await _writeFlags(
      row,
      publicKey,
      favourite ? row.flags | 1 : row.flags & ~1,
    );
  }

  /// Lets [publicKey] run commands on this radio, or stops them.
  /// Sends [packet] again exactly as it was heard. Throws when the radio
  /// refuses, which older firmware does.
  Future<void> resendPacket(Uint8List packet) =>
      _session.run(SendRawPacket(packet));

  Future<void> setRemoteCommandsAllowed(
    PublicKey publicKey, {
    required bool allowed,
  }) async {
    final key = _requireKey();
    final row = await _store.contact(key, publicKey.hex);
    if (row == null) return;
    await _writeFlags(
      row,
      publicKey,
      allowed
          ? row.flags | contactFlagRemoteCommands
          : row.flags & ~contactFlagRemoteCommands,
    );
  }

  Future<void> _writeFlags(Contact row, PublicKey publicKey, int flags) async {
    await _session.run(
      AddOrUpdateContact(
        RadioContact(
          publicKey: publicKey,
          type: NodeType.fromByte(row.type),
          flags: flags,
          outPathLength: row.outPathLength,
          outPath: row.outPath,
          name: row.name,
          lastAdvert: row.lastAdvert,
          latitude: row.latitude,
          longitude: row.longitude,
          // A fresh time, so the next contact sync picks the change up.
          lastModified: _seconds(null),
        ),
      ),
    );
    await _syncContacts();
  }

  /// Clears the time of [contact]'s last advert on the radio. The radio
  /// ignores adverts older than the last one it saw, so a node whose clock
  /// was reset stops updating until this is done.
  Future<void> forgetLastAdvert(PublicKey publicKey) async {
    final key = _requireKey();
    final row = await _store.contact(key, publicKey.hex);
    if (row == null) return;
    await _session.run(
      AddOrUpdateContact(
        RadioContact(
          publicKey: publicKey,
          type: NodeType.fromByte(row.type),
          flags: row.flags,
          outPathLength: row.outPathLength,
          outPath: row.outPath,
          name: row.name,
          lastAdvert: 0,
          latitude: row.latitude,
          longitude: row.longitude,
          lastModified: _seconds(null),
        ),
      ),
    );
    await _syncContacts();
  }

  /// Forgets the radio's route to [contact], so the next message floods and
  /// a fresh route is learned.
  Future<void> resetRoute(PublicKey contact) async {
    await _session.run(ResetPath(contact));
    await _syncContacts();
  }

  /// Sets the route the radio uses for direct messages to [contact]:
  /// [path] is the hop hashes, nearest repeater first, each [hashBytes]
  /// long (1 to 3). An empty [path] means a direct neighbour.
  Future<void> setRoute(
    PublicKey contact,
    List<int> path, {
    required int hashBytes,
  }) async {
    if (hashBytes < 1 || hashBytes > 3 || path.length % hashBytes != 0) {
      throw ArgumentError.value(path, 'path');
    }
    final hops = path.length ~/ hashBytes;
    if (hops >= 64 || path.length > maxPathSize) {
      throw ArgumentError.value(path, 'path', 'too long');
    }
    final key = _requireKey();
    final row = await _store.contact(key, contact.hex);
    if (row == null) throw ArgumentError.value(contact.hex, 'contact');
    await _session.run(
      AddOrUpdateContact(
        RadioContact(
          publicKey: contact,
          type: NodeType.fromByte(row.type),
          flags: row.flags,
          outPathLength: ((hashBytes - 1) << 6) | hops,
          outPath: path,
          name: row.name,
          lastAdvert: row.lastAdvert,
          latitude: row.latitude,
          longitude: row.longitude,
          lastModified: _seconds(null),
        ),
      ),
    );
    await _syncContacts();
  }

  /// Sends this radio's advert so others can find it: to neighbours only,
  /// or flooded across the mesh.
  Future<void> sendAdvert({bool flood = false}) =>
      _session.run(SendSelfAdvert(flood: flood));

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Repeaters and room servers

  /// Logs in to a repeater or room server. A wrong password gets no reply
  /// at all from the firmware, so that shows up as [LoginNoReply].
  Future<LoginResult> login(PublicKey server, String password) async {
    final prefix = server.prefix();
    final reply = _session.pushes
        .where(
          (p) => switch (p) {
            LoginSucceeded(:final serverPrefix) ||
            LoginFailed(
              :final serverPrefix,
            ) => _sameBytes(serverPrefix, prefix),
            _ => false,
          },
        )
        .first;
    // If sending fails or the link drops, nobody awaits this; don't let
    // its error go unhandled.
    reply.ignore();
    final sent = await _session.request<SentReply>(
      SendLogin(server: server, password: password),
    );
    try {
      final push = await reply.timeout(_replyWait(sent));
      return switch (push) {
        LoginSucceeded() => LoggedIn(ServerRole.from(push)),
        _ => const LoginRefused(),
      };
    } on TimeoutException {
      return const LoginNoReply();
    }
  }

  /// Sends a trace along [hops] and waits for it to come back. Null if it
  /// doesn't return in time, which usually means a hop is out of reach.
  Future<TraceData?> trace(
    List<List<int>> hops, {
    required int hashBytes,
  }) async {
    final tag = math.Random().nextInt(0x7FFFFFFF) + 1;
    final reply = _session.pushes
        .where((p) => p is TraceData && p.tag == tag)
        .first;
    reply.ignore();
    final sent = await _session.request<SentReply>(
      SendTracePath(tag: tag, hops: hops, hashBytes: hashBytes),
    );
    try {
      return await reply.timeout(_replyWait(sent)) as TraceData;
    } on TimeoutException {
      return null;
    }
  }

  Future<void> logout(PublicKey server) => _session.run(Logout(server));

  /// Asks a repeater or room server for its status. Null if it doesn't
  /// answer in time.
  Future<ServerStatus?> requestStatus(PublicKey server) async {
    final prefix = server.prefix();
    final reply = _session.pushes
        .where((p) => p is StatusResponse && _sameBytes(p.serverPrefix, prefix))
        .first;
    reply.ignore();
    final sent = await _session.request<SentReply>(SendStatusRequest(server));
    try {
      final push = await reply.timeout(_replyWait(sent)) as StatusResponse;
      return ServerStatus.parse(push.data);
    } on TimeoutException {
      return null;
    }
  }

  /// Asks [node] for its sensor readings, or the connected radio itself
  /// when [node] is null, and stores the reply in the telemetry history.
  /// Null if nothing arrives in time. Repeaters and rooms only answer after
  /// a login.
  Future<List<LppReading>?> requestTelemetry([PublicKey? node]) async {
    final key = _requireKey();
    final nodeKey = node ?? PublicKey.fromHex(key);
    final prefix = nodeKey.prefix();
    final reply = _session.pushes
        .where(
          (p) => p is TelemetryResponse && _sameBytes(p.nodePrefix, prefix),
        )
        .first;
    reply.ignore();
    final Duration wait;
    if (node == null) {
      // The radio answers itself with the push alone, no other reply.
      await _session.sendOnly(const SendTelemetryRequest());
      wait = selfTelemetryWait;
    } else {
      final sent = await _session.request<SentReply>(
        SendTelemetryRequest(node),
      );
      wait = _replyWait(sent);
    }
    try {
      final push = await reply.timeout(wait) as TelemetryResponse;
      await _store.saveTelemetry(key, nodeKey.hex, push.data);
      return decodeLpp(push.data);
    } on TimeoutException {
      return null;
    }
  }

  /// Sends a console command to a server you're logged in to as admin. The
  /// reply arrives as console text in the same thread. Returns the stored
  /// command's id.
  Future<int> sendCommand(
    PublicKey server,
    String command, {
    DateTime? now,
    TextType type = TextType.cliData,
  }) async {
    final key = _requireKey();
    _checkDirectText(command);
    final sentAt = _seconds(now);
    final id = await _store.saveOutgoing(
      key,
      thread: Threads.direct(server.hex),
      body: command,
      sentAt: sentAt,
      textType: TextType.cliData.value,
    );
    try {
      final sent = await _session.request<SentReply>(
        SendTextMessage(
          recipient: server,
          text: command,
          timestamp: sentAt,
          type: type,
        ),
      );
      await _store.markSent(id, flooded: sent.flooded);
    } on RadioRequestException {
      await _store.markFailed(id);
      rethrow;
    }
    return id;
  }

  /// How long to wait for a server's reply: the radio's own estimate plus
  /// time for the server to answer, within sensible bounds.
  Duration _replyWait(SentReply sent) => Duration(
    milliseconds: (sent.timeoutMs * 2 + 5000).clamp(
      serverReplyFloor.inMilliseconds,
      60000,
    ),
  );

  /// Sends to a channel slot and stores it. Channel messages have no ack, so
  /// they end at sent.
  ///
  /// With [region] the post is scoped to it, and only repeaters allowing
  /// that region pass it on. If the radio can't scope, it still goes out,
  /// unscoped.
  Future<int> sendChannel(
    int slot,
    String text, {
    DateTime? now,
    String? region,
    bool signed = false,
  }) {
    final sentAt = _seconds(now);
    final command = SendChannelText(
      channel: slot,
      text: text,
      timestamp: sentAt,
    );
    return _send(Threads.channel(slot), text, sentAt, command, (id) async {
      final scoped = region != null && await _setScope(regionKey(region));
      try {
        await _session.run(command);
      } finally {
        // Direct messages and SOS must never pick up the region.
        if (scoped) await _setScope(null);
      }
      if (scoped) await _store.setMessageRegion(id, region);
      await _store.markSent(id);
      // The post is out. Signing follows on its own, so it never holds up
      // an SOS, and a failed signature can't make the post look unsent.
      if (signed) {
        unawaited(
          _signPost(id, slot, sentAt, text).catchError((Object e) {
            if (!_errors.isClosed) _errors.add(e);
          }),
        );
      }
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
    await _incoming.close();
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

  /// Sends [jpeg] to channel [slot]: a caption post first, then the pieces,
  /// [gap] apart so they don't crowd the channel. The photo is stored here
  /// too, so it shows in this chat.
  Future<void> sendPhoto(
    int slot,
    Uint8List jpeg, {
    Duration gap = const Duration(milliseconds: 1500),
  }) async {
    final key = _requireKey();
    final id = newPhotoId();
    final chunks = photoChunks(id, jpeg);
    for (final c in chunks) {
      final p = parsePhotoChunk(c)!;
      await _store.savePhotoChunk(key, id, p.index, p.count, p.data);
    }
    await sendChannel(slot, photoCaption(id));
    for (final c in chunks) {
      await Future<void>.delayed(gap);
      await _session.run(
        SendChannelData(
          channel: slot,
          dataType: signedPostDataType,
          payload: c,
        ),
      );
    }
  }

  /// Has the radio sign [data] with its own key.
  Future<Uint8List> sign(List<int> data) async {
    await _session.request<SignStartReply>(const SignStart());
    for (var i = 0; i < data.length; i += 128) {
      final end = math.min(i + 128, data.length);
      await _session.run(SignData(data.sublist(i, end)));
    }
    return (await _session.request<SignatureReply>(const SignFinish()))
        .signature;
  }

  Future<void> _signPost(int id, int slot, int sentAt, String text) async {
    final radio = _radio;
    if (radio == null) return;
    final channel = [
      for (final c in await _store.watchChannels(radio.key).first)
        if (c.slot == slot) c,
    ].firstOrNull;
    if (channel == null) return;
    final signature = await sign(
      signedBytes(
        channelSecret: channel.secret,
        sentAt: sentAt,
        post: '${radio.self.name}: $text',
      ),
    );
    await _session.run(
      SendChannelData(
        channel: slot,
        dataType: signedPostDataType,
        payload: encodePostSignature((
          sentAt: sentAt,
          signer: radio.self.publicKey.bytes,
          signature: signature,
        )),
      ),
    );
    await _store.setSignature(id, radio.self.publicKey.hex, valid: true);
  }

  /// Signatures that arrived before their post, by `slot:sentAt`.
  final _pendingSignatures = <String, PostSignature>{};

  Future<void> _checkSignature(String key, int slot, PostSignature s) async {
    final post = await _store.channelPostAt(key, slot, s.sentAt);
    if (post == null) {
      _pendingSignatures['$slot:${s.sentAt}'] = s;
      if (_pendingSignatures.length > 64) {
        _pendingSignatures.remove(_pendingSignatures.keys.first);
      }
      return;
    }
    final channel = [
      for (final c in await _store.watchChannels(key).first)
        if (c.slot == slot) c,
    ].firstOrNull;
    if (channel == null) return;
    final text = post.senderName == null
        ? post.body
        : '${post.senderName}: ${post.body}';
    final valid = verifyPostSignature(
      s,
      signedBytes(channelSecret: channel.secret, sentAt: s.sentAt, post: text),
    );
    await _store.setSignature(post.id, toHex(s.signer), valid: valid);
  }

  /// Whether the radio accepted scope [key].
  Future<bool> _setScope(Uint8List? key) async {
    try {
      await _session.run(SetFloodScope(key));
      return true;
    } on Object {
      return false;
    }
  }

  /// Remembers which region a heard post was in, so the message can be
  /// tagged when the radio hands it over.
  Future<void> _noteRegion(String key, RxLog log) async {
    final regions = regionNames(
      '${await _store.setting(regionSendSetting) ?? ''},'
      '${await _store.setting(regionKnownSetting) ?? ''}',
    );
    if (regions.isEmpty) return;
    final post = scopedPost(log.packet, regions);
    if (post == null) return;
    for (final channel in await _store.watchChannels(key).first) {
      if (sha256.convert(channel.secret).bytes.first != post.channelHash) {
        continue;
      }
      final time = channelPostTime(post.payload, channel.secret);
      if (time == null) continue;
      _heardRegions['${channel.slot}:$time'] = post.region;
      if (_heardRegions.length > 64) {
        _heardRegions.remove(_heardRegions.keys.first);
      }
    }
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
        final stored = await _store.saveIncoming(
          key,
          event as ReplyFrame,
          region: event is ChannelMessage
              ? _heardRegions.remove('${event.channel}:${event.timestamp}')
              : null,
        );
        if (stored != null && !_incoming.isClosed) _incoming.add(stored);
        if (event is ChannelMessage) {
          final waiting = _pendingSignatures.remove(
            '${event.channel}:${event.timestamp}',
          );
          if (waiting != null) {
            await _checkSignature(key, event.channel, waiting);
          }
        }
      case ChannelData(:final dataType, :final payload)
          when dataType == signedPostDataType &&
              parsePhotoChunk(payload) != null:
        final c = parsePhotoChunk(payload)!;
        await _store.savePhotoChunk(key, c.id, c.index, c.count, c.data);
      case ChannelData(:final channel, :final dataType, :final payload)
          when dataType == signedPostDataType:
        final s = decodePostSignature(payload);
        if (s != null) await _checkSignature(key, channel, s);
      case final RxLog log:
        await _noteRegion(key, log);
      case NewAdvert(:final contact):
        // The radio only sends this for nodes it did NOT add, so it belongs
        // in "heard nearby", not in the contact list.
        await _store.saveDiscovered(key, contact);
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
