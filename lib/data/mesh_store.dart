import 'package:drift/drift.dart';

import '../radio/radio.dart';
import 'database.dart';

/// Thread ids group messages into conversations.
abstract final class Threads {
  /// A direct conversation, by the contact's full key or, when the sender
  /// isn't a known contact yet, the 6-byte prefix the radio reported.
  static String direct(String keyOrPrefixHex) => 'd:$keyOrPrefixHex';

  static String channel(int slot) => 'c:$slot';
}

/// Reads and writes what the app keeps about each radio. Every method takes
/// the radio's key, because a phone can be paired with several radios.
class MeshStore {
  MeshStore(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final MeshDatabase _db;
  final DateTime Function() _clock;

  // Radios

  /// Records a connection to the radio described by [self].
  Future<void> rememberRadio(SelfInfo self) {
    return _db
        .into(_db.radios)
        .insert(
          RadiosCompanion.insert(
            publicKey: self.publicKey.hex,
            name: self.name,
            lastConnectedAt: _clock().millisecondsSinceEpoch,
          ),
          onConflict: DoUpdate(
            (_) => RadiosCompanion(
              name: Value(self.name),
              lastConnectedAt: Value(_clock().millisecondsSinceEpoch),
            ),
          ),
        );
  }

  Future<Radio?> radio(String radioKey) => (_db.select(
    _db.radios,
  )..where((r) => r.publicKey.equals(radioKey))).getSingleOrNull();

  /// Radios most recently used first, for reconnecting.
  Stream<List<Radio>> watchRadios() => (_db.select(
    _db.radios,
  )..orderBy([(r) => OrderingTerm.desc(r.lastConnectedAt)])).watch();

  // Settings

  Future<String?> setting(String key) async => (await (_db.select(
    _db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> saveSetting(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> removeSetting(String key) =>
      (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();

  /// Settings whose key starts with [prefix], keyed by the rest of the key.
  Stream<Map<String, String>> watchSettingsWithPrefix(String prefix) =>
      (_db.select(_db.settings)
            ..where((s) => s.key.substr(1, prefix.length).equals(prefix)))
          .watch()
          .map(
            (rows) => {
              for (final r in rows) r.key.substring(prefix.length): r.value,
            },
          );

  // Drafts

  static String _draftPrefix(String radioKey) => 'draft:$radioKey:';

  /// Text typed in [thread] but not sent, or null.
  Future<String?> draft(String radioKey, String thread) =>
      setting('${_draftPrefix(radioKey)}$thread');

  /// Remembers unsent [text] for [thread]; blank text forgets it.
  Future<void> saveDraft(String radioKey, String thread, String text) {
    final key = '${_draftPrefix(radioKey)}$thread';
    return text.trim().isEmpty ? removeSetting(key) : saveSetting(key, text);
  }

  /// Unsent text of every chat, by thread.
  Stream<Map<String, String>> watchDrafts(String radioKey) =>
      watchSettingsWithPrefix(_draftPrefix(radioKey));

  // Contacts

  /// Saves a contact download. [since] is what was passed to the download:
  /// after a full one (0 or null), contacts the radio no longer has are
  /// removed here too.
  Future<void> saveContacts(String radioKey, ContactSync sync, {int? since}) {
    return _db.transaction(() async {
      final full = since == null || since == 0;
      await _db.batch((batch) {
        for (final contact in sync.contacts) {
          batch.insert(
            _db.contacts,
            _contactRow(radioKey, contact),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      if (full) {
        final keep = [for (final c in sync.contacts) c.publicKey.hex];
        await (_db.delete(_db.contacts)..where(
              (c) => c.radioKey.equals(radioKey) & c.publicKey.isNotIn(keep),
            ))
            .go();
      }
      final newest = sync.newestModified;
      await (_db.update(_db.radios)..where(
            (r) =>
                r.publicKey.equals(radioKey) &
                r.contactsSince.isSmallerThanValue(newest),
          ))
          .write(RadiosCompanion(contactsSince: Value(newest)));
    });
  }

  /// Adds or refreshes one contact, such as from a new-advert push.
  Future<void> saveContact(String radioKey, RadioContact contact) => _db
      .into(_db.contacts)
      .insert(_contactRow(radioKey, contact), mode: InsertMode.insertOrReplace);

  Future<void> removeContact(String radioKey, PublicKey key) =>
      (_db.delete(_db.contacts)..where(
            (c) => c.radioKey.equals(radioKey) & c.publicKey.equals(key.hex),
          ))
          .go();

  Stream<List<Contact>> watchContacts(String radioKey) =>
      (_db.select(_db.contacts)
            ..where((c) => c.radioKey.equals(radioKey))
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  /// The contact whose key starts with [prefix], if exactly one does.
  Future<Contact?> contactByPrefix(String radioKey, List<int> prefix) async {
    final matches =
        await (_db.select(_db.contacts)
              ..where(
                (c) =>
                    c.radioKey.equals(radioKey) &
                    c.publicKey.like('${toHex(prefix)}%'),
              )
              ..limit(2))
            .get();
    return matches.length == 1 ? matches.single : null;
  }

  ContactsCompanion _contactRow(String radioKey, RadioContact c) =>
      ContactsCompanion.insert(
        radioKey: radioKey,
        publicKey: c.publicKey.hex,
        name: c.name,
        type: c.type.value,
        flags: c.flags,
        outPathLength: c.outPathLength,
        outPath: c.route,
        lastAdvert: c.lastAdvert,
        latitude: Value(c.latitude),
        longitude: Value(c.longitude),
        lastModified: c.lastModified,
      );

  // Heard nearby

  /// Records a node the radio heard but didn't add.
  Future<void> saveDiscovered(String radioKey, RadioContact node) => _db
      .into(_db.discovered)
      .insertOnConflictUpdate(
        DiscoveredCompanion.insert(
          radioKey: radioKey,
          publicKey: node.publicKey.hex,
          name: node.name,
          type: node.type.value,
          latitude: Value(node.latitude),
          longitude: Value(node.longitude),
          lastAdvert: node.lastAdvert,
          heardAt: _clock().millisecondsSinceEpoch,
        ),
      );

  Future<void> removeDiscovered(String radioKey, String publicKeyHex) =>
      (_db.delete(_db.discovered)..where(
            (d) =>
                d.radioKey.equals(radioKey) & d.publicKey.equals(publicKeyHex),
          ))
          .go();

  /// Nodes heard but not added, most recently heard first. Anything that is
  /// already a contact is left out.
  Stream<List<DiscoveredData>> watchDiscovered(String radioKey) {
    final known = _db.selectOnly(_db.contacts)
      ..addColumns([_db.contacts.publicKey])
      ..where(_db.contacts.radioKey.equals(radioKey));
    return (_db.select(_db.discovered)
          ..where(
            (d) =>
                d.radioKey.equals(radioKey) & d.publicKey.isNotInQuery(known),
          )
          ..orderBy([(d) => OrderingTerm.desc(d.heardAt)]))
        .watch();
  }

  Future<Contact?> contact(String radioKey, String publicKeyHex) =>
      (_db.select(_db.contacts)..where(
            (c) =>
                c.radioKey.equals(radioKey) & c.publicKey.equals(publicKeyHex),
          ))
          .getSingleOrNull();

  // Channels

  /// Replaces the stored slots with what the radio reported. Empty slots are
  /// dropped.
  Future<void> saveChannels(String radioKey, List<ChannelInfo> slots) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.channels,
      )..where((c) => c.radioKey.equals(radioKey))).go();
      await _db.batch((batch) {
        for (final slot in slots.where((s) => !s.isEmpty)) {
          batch.insert(
            _db.channels,
            ChannelsCompanion.insert(
              radioKey: radioKey,
              slot: slot.index,
              name: slot.name,
              secret: slot.secret,
            ),
          );
        }
      });
    });
  }

  Stream<List<Channel>> watchChannels(String radioKey) =>
      (_db.select(_db.channels)
            ..where((c) => c.radioKey.equals(radioKey))
            ..orderBy([(c) => OrderingTerm.asc(c.slot)]))
          .watch();

  // Messages

  /// Stores a message from the radio. Returns the new row, or null when the
  /// same message was already stored (radios can deliver one twice).
  Future<Message?> saveIncoming(String radioKey, ReplyFrame frame) async {
    final MessagesCompanion row;
    switch (frame) {
      case ContactMessage():
        final contact = await contactByPrefix(radioKey, frame.senderPrefix);
        final prefix = toHex(frame.senderPrefix);
        final signer = frame.signerPrefix;
        final author = signer == null ? null : toHex(signer);
        row = _incoming(
          radioKey,
          kind: MessageKind.direct,
          thread: Threads.direct(contact?.publicKey ?? prefix),
          body: frame.text,
          sentAt: frame.timestamp,
          pathLength: frame.pathLength,
          snr: frame.snr,
          textType: frame.type.value,
          authorPrefix: author,
          // Room posts from different members can share a time and text.
          dedupeKey:
              'd:$prefix:${author ?? ''}:${frame.timestamp}:${frame.text}',
        );
      case ChannelMessage():
        final parts = frame.senderAndBody;
        row = _incoming(
          radioKey,
          kind: MessageKind.channel,
          thread: Threads.channel(frame.channel),
          body: parts.body,
          senderName: parts.sender,
          sentAt: frame.timestamp,
          pathLength: frame.pathLength,
          snr: frame.snr,
          dedupeKey: 'c:${frame.channel}:${frame.timestamp}:${frame.text}',
        );
      default:
        return null;
    }
    return _db
        .into(_db.messages)
        .insertReturningOrNull(row, mode: InsertMode.insertOrIgnore);
  }

  MessagesCompanion _incoming(
    String radioKey, {
    required MessageKind kind,
    required String thread,
    required String body,
    required int sentAt,
    required int pathLength,
    required double? snr,
    required String dedupeKey,
    String? senderName,
    int textType = 0,
    String? authorPrefix,
  }) => MessagesCompanion.insert(
    radioKey: radioKey,
    kind: kind,
    thread: thread,
    outgoing: false,
    body: body,
    senderName: Value(senderName),
    sentAt: sentAt,
    storedAt: _clock().millisecondsSinceEpoch,
    status: MessageStatus.received,
    pathLength: Value(pathLength),
    snr: Value(snr),
    dedupeKey: Value(dedupeKey),
    textType: Value(textType),
    authorPrefix: Value(authorPrefix),
  );

  /// Stores a message about to be sent, as pending. Returns its id.
  Future<int> saveOutgoing(
    String radioKey, {
    required String thread,
    required String body,
    required int sentAt,
    int textType = 0,
  }) => _db
      .into(_db.messages)
      .insert(
        MessagesCompanion.insert(
          textType: Value(textType),
          radioKey: radioKey,
          kind: thread.startsWith('c:')
              ? MessageKind.channel
              : MessageKind.direct,
          thread: thread,
          outgoing: true,
          body: body,
          sentAt: sentAt,
          storedAt: _clock().millisecondsSinceEpoch,
          status: MessageStatus.pending,
        ),
      );

  /// The messages with these [ids], as they change (for delivery status).
  Stream<List<Message>> watchMessagesById(List<int> ids) => ids.isEmpty
      ? Stream.value(const [])
      : (_db.select(_db.messages)..where((m) => m.id.isIn(ids))).watch();

  /// When the newest message from the other side of [thread] was stored,
  /// or null if none ever arrived.
  Future<DateTime?> lastIncomingAt(String radioKey, String thread) async {
    final row =
        await (_db.select(_db.messages)
              ..where(
                (m) =>
                    m.radioKey.equals(radioKey) &
                    m.thread.equals(thread) &
                    m.outgoing.equals(false),
              )
              ..orderBy([(m) => OrderingTerm.desc(m.id)])
              ..limit(1))
            .getSingleOrNull();
    return row == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.storedAt);
  }

  /// The radio accepted the message. Direct messages carry the [ackCode]
  /// their delivery confirmation will match, and how many [attempts] have
  /// been sent so far.
  Future<void> markSent(
    int id, {
    int? ackCode,
    bool? flooded,
    int attempts = 1,
  }) =>
      (_db.update(_db.messages)..where(
            // An ack can land before this write; never undo a delivery.
            (m) =>
                m.id.equals(id) &
                m.status.equalsValue(MessageStatus.delivered).not(),
          ))
          .write(
            MessagesCompanion(
              status: const Value(MessageStatus.sent),
              ackCode: Value(ackCode),
              flooded: Value(flooded),
              attempts: Value(attempts),
            ),
          );

  /// Marks message [id] delivered, if it was still waiting.
  Future<void> markDeliveredById(int id) =>
      (_db.update(_db.messages)..where(
            (m) =>
                m.id.equals(id) &
                m.status.isIn([
                  MessageStatus.pending.index,
                  MessageStatus.sent.index,
                  MessageStatus.failed.index,
                ]),
          ))
          .write(
            const MessagesCompanion(status: Value(MessageStatus.delivered)),
          );

  /// Puts a failed message back to pending for a resend.
  Future<void> markPending(int id) =>
      (_db.update(_db.messages)..where((m) => m.id.equals(id))).write(
        const MessagesCompanion(status: Value(MessageStatus.pending)),
      );

  Future<Message?> message(int id) => (_db.select(
    _db.messages,
  )..where((m) => m.id.equals(id))).getSingleOrNull();

  /// Outgoing messages still pending from an earlier run (the app closed
  /// mid-send) become failed, so they can be resent.
  Future<void> failStalePending(String radioKey) =>
      (_db.update(_db.messages)..where(
            (m) =>
                m.radioKey.equals(radioKey) &
                m.outgoing.equals(true) &
                m.status.equalsValue(MessageStatus.pending),
          ))
          .write(const MessagesCompanion(status: Value(MessageStatus.failed)));

  /// Marks the sent message with [ackCode] as delivered. Returns whether one
  /// matched; acks can arrive more than once.
  Future<bool> markDelivered(String radioKey, int ackCode) async {
    final changed =
        await (_db.update(_db.messages)..where(
              (m) =>
                  m.radioKey.equals(radioKey) &
                  m.ackCode.equals(ackCode) &
                  m.status.equalsValue(MessageStatus.sent),
            ))
            .write(
              const MessagesCompanion(status: Value(MessageStatus.delivered)),
            );
    return changed > 0;
  }

  Future<void> markFailed(int id) =>
      (_db.update(_db.messages)..where((m) => m.id.equals(id))).write(
        const MessagesCompanion(status: Value(MessageStatus.failed)),
      );

  /// The newest message in each conversation, newest conversation first.
  Stream<List<Message>> watchConversations(String radioKey) {
    final latest = _db.messages.id.max();
    final newestIds = _db.selectOnly(_db.messages)
      ..addColumns([latest])
      ..where(
        _db.messages.radioKey.equals(radioKey) &
            _db.messages.textType.equals(TextType.cliData.value).not() &
            CustomExpression<bool>(notBlockedSql('')),
      )
      ..groupBy([_db.messages.thread]);
    return (_db.select(_db.messages)
          ..where((m) => m.id.isInQuery(newestIds))
          ..orderBy([(m) => OrderingTerm.desc(m.id)]))
        .watch();
  }

  // Blocking

  /// Setting keys holding blocked senders as JSON lists: channel senders by
  /// the name they post under, direct senders by public key (hex).
  static const blockedNamesSetting = 'blocked_names';
  static const blockedKeysSetting = 'blocked_keys';

  /// SQL that is true unless the message (columns prefixed with [p], such
  /// as `m.`) came from a blocked sender.
  static String notBlockedSql(String p) =>
      'NOT (${p}outgoing = 0 AND ('
      '(${p}kind = ${MessageKind.channel.index} AND ${p}sender_name IN '
      '(SELECT value FROM json_each(COALESCE((SELECT value FROM settings '
      "WHERE key = '$blockedNamesSetting'), '[]')))) OR "
      '(${p}kind = ${MessageKind.direct.index} AND substr(${p}thread, 3) IN '
      '(SELECT value FROM json_each(COALESCE((SELECT value FROM settings '
      "WHERE key = '$blockedKeysSetting'), '[]'))))))";

  // Unread and muting

  /// Unread incoming messages per thread; threads with none are left out.
  Stream<Map<String, int>> watchUnreadCounts(String radioKey) => _db
      .customSelect(
        'SELECT m.thread AS thread, COUNT(*) AS unread FROM messages m '
        'LEFT JOIN thread_states t '
        'ON t.radio_key = m.radio_key AND t.thread = m.thread '
        'WHERE m.radio_key = ? AND m.outgoing = 0 AND m.text_type != 1 '
        'AND m.id > COALESCE(t.last_read_id, 0) '
        'AND ${notBlockedSql('m.')} '
        'GROUP BY m.thread',
        variables: [Variable.withString(radioKey)],
        readsFrom: {_db.messages, _db.threadStates, _db.settings},
      )
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            row.read<String>('thread'): row.read<int>('unread'),
        },
      );

  /// Marks everything in [thread] up to now as read.
  Future<void> markRead(String radioKey, String thread) async {
    final newest = _db.messages.id.max();
    final row =
        await (_db.selectOnly(_db.messages)
              ..addColumns([newest])
              ..where(
                _db.messages.radioKey.equals(radioKey) &
                    _db.messages.thread.equals(thread),
              ))
            .getSingle();
    final id = row.read(newest);
    if (id == null) return;
    await _db
        .into(_db.threadStates)
        .insert(
          ThreadStatesCompanion.insert(
            radioKey: radioKey,
            thread: thread,
            lastReadId: Value(id),
          ),
          onConflict: DoUpdate(
            (old) => ThreadStatesCompanion.custom(lastReadId: Constant(id)),
            where: (old) => old.lastReadId.isSmallerThanValue(id),
          ),
        );
  }

  Future<void> setMuted(String radioKey, String thread, bool muted) => _db
      .into(_db.threadStates)
      .insert(
        ThreadStatesCompanion.insert(
          radioKey: radioKey,
          thread: thread,
          muted: Value(muted),
        ),
        onConflict: DoUpdate(
          (old) => ThreadStatesCompanion(muted: Value(muted)),
        ),
      );

  /// Threads whose new messages shouldn't notify.
  Stream<Set<String>> watchMuted(String radioKey) =>
      (_db.select(_db.threadStates)
            ..where((t) => t.radioKey.equals(radioKey) & t.muted.equals(true)))
          .watch()
          .map((rows) => {for (final r in rows) r.thread});

  Future<bool> isMuted(String radioKey, String thread) async =>
      (await (_db.select(_db.threadStates)..where(
                (t) => t.radioKey.equals(radioKey) & t.thread.equals(thread),
              ))
              .getSingleOrNull())
          ?.muted ??
      false;

  /// Chat messages containing [query] (case-insensitive), newest first.
  /// Console text is left out.
  Future<List<Message>> searchMessages(
    String radioKey,
    String query, {
    int limit = 100,
  }) {
    final words = query.trim();
    if (words.isEmpty) return Future.value(const []);
    // Escape LIKE wildcards so "50%" matches literally.
    final pattern =
        '%${words.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    return (_db.select(_db.messages)
          ..where(
            (m) =>
                m.radioKey.equals(radioKey) &
                m.textType.equals(TextType.cliData.value).not() &
                (m.body.like(pattern, escapeChar: r'\') |
                    m.senderName.like(pattern, escapeChar: r'\')),
          )
          ..orderBy([(m) => OrderingTerm.desc(m.id)])
          ..limit(limit))
        .get();
  }

  /// A conversation as it is now, oldest first.
  Future<List<Message>> threadSnapshot(
    String radioKey,
    String thread, {
    bool console = false,
  }) => _thread(radioKey, thread, console).get();

  /// A conversation, oldest first. With [console], the command text
  /// exchanged with a server instead of chat.
  Stream<List<Message>> watchThread(
    String radioKey,
    String thread, {
    bool console = false,
  }) => _thread(radioKey, thread, console).watch();

  SimpleSelectStatement<$MessagesTable, Message> _thread(
    String radioKey,
    String thread,
    bool console,
  ) {
    final cli = _db.messages.textType.equals(TextType.cliData.value);
    return _db.select(_db.messages)
      ..where(
        (m) =>
            m.radioKey.equals(radioKey) &
            m.thread.equals(thread) &
            (console ? cli : cli.not()),
      )
      ..orderBy([(m) => OrderingTerm.asc(m.id)]);
  }

  // Telemetry

  /// How many readings are kept per node. Older ones are dropped.
  static const telemetryKept = 1000;

  /// Stores a telemetry reply from [nodeKey] (hex) and drops the oldest
  /// beyond [telemetryKept].
  Future<void> saveTelemetry(String radioKey, String nodeKey, List<int> data) =>
      _db.transaction(() async {
        await _db
            .into(_db.telemetrySamples)
            .insert(
              TelemetrySamplesCompanion.insert(
                radioKey: radioKey,
                nodeKey: nodeKey,
                at: _clock().millisecondsSinceEpoch,
                data: Uint8List.fromList(data),
              ),
            );
        await _db.customStatement(
          'DELETE FROM telemetry_samples WHERE radio_key = ? AND node_key = ? '
          'AND id NOT IN (SELECT id FROM telemetry_samples '
          'WHERE radio_key = ? AND node_key = ? ORDER BY id DESC LIMIT ?)',
          [radioKey, nodeKey, radioKey, nodeKey, telemetryKept],
        );
      });

  /// A node's telemetry history, oldest first.
  Stream<List<TelemetrySample>> watchTelemetry(
    String radioKey,
    String nodeKey,
  ) =>
      (_db.select(_db.telemetrySamples)
            ..where(
              (t) => t.radioKey.equals(radioKey) & t.nodeKey.equals(nodeKey),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  /// When the newest reading from [nodeKey] arrived, or null if none.
  Future<DateTime?> lastTelemetryAt(String radioKey, String nodeKey) async {
    final row =
        await (_db.select(_db.telemetrySamples)
              ..where(
                (t) => t.radioKey.equals(radioKey) & t.nodeKey.equals(nodeKey),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : DateTime.fromMillisecondsSinceEpoch(row.at);
  }

  /// Forgets a node's telemetry history.
  Future<void> clearTelemetry(String radioKey, String nodeKey) =>
      (_db.delete(_db.telemetrySamples)..where(
            (t) => t.radioKey.equals(radioKey) & t.nodeKey.equals(nodeKey),
          ))
          .go();

  /// The newest telemetry reply from each node, by node key.
  Stream<Map<String, TelemetrySample>> watchLatestTelemetry(String radioKey) =>
      (_db.select(_db.telemetrySamples)..where(
            (t) => t.id.isInQuery(
              _db.selectOnly(_db.telemetrySamples)
                ..addColumns([_db.telemetrySamples.id.max()])
                ..where(_db.telemetrySamples.radioKey.equals(radioKey))
                ..groupBy([_db.telemetrySamples.nodeKey]),
            ),
          ))
          .watch()
          .map((rows) => {for (final r in rows) r.nodeKey: r});

  /// Deletes channel messages stored more than [age] ago, on every radio,
  /// and returns how many went. Direct messages are never touched.
  Future<int> deleteOldChannelMessages(Duration age) =>
      (_db.delete(_db.messages)..where(
            (m) =>
                m.thread.like('c:%') &
                m.storedAt.isSmallerThanValue(
                  _clock().subtract(age).millisecondsSinceEpoch,
                ),
          ))
          .go();

  // Track log

  /// Starts a new track and returns its id.
  Future<int> startTrack(String name) => _db
      .into(_db.tracks)
      .insert(
        TracksCompanion.insert(
          name: name,
          startedAt: _clock().millisecondsSinceEpoch,
        ),
      );

  /// Adds one fix to track [id].
  Future<void> addTrackPoint(
    int id, {
    required double latitude,
    required double longitude,
    double? altitude,
  }) => _db
      .into(_db.trackPoints)
      .insert(
        TrackPointsCompanion.insert(
          track: id,
          at: _clock().millisecondsSinceEpoch,
          latitude: latitude,
          longitude: longitude,
          altitude: Value(altitude),
        ),
      );

  /// Ends every track still open, including one left by a closed app.
  Future<void> endOpenTracks() =>
      (_db.update(_db.tracks)..where((t) => t.endedAt.isNull())).write(
        TracksCompanion(endedAt: Value(_clock().millisecondsSinceEpoch)),
      );

  /// All tracks, newest first.
  Stream<List<Track>> watchTracks() => (_db.select(
    _db.tracks,
  )..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();

  /// A track's fixes, oldest first.
  Stream<List<TrackPoint>> watchTrackPoints(int id) =>
      (_db.select(_db.trackPoints)
            ..where((t) => t.track.equals(id))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  /// Deletes a track and its fixes.
  Future<void> deleteTrack(int id) => _db.transaction(() async {
    await (_db.delete(_db.trackPoints)..where((t) => t.track.equals(id))).go();
    await (_db.delete(_db.tracks)..where((t) => t.id.equals(id))).go();
  });

  // Radio stats

  /// How many receiver samples are kept per radio: about two weeks at one
  /// every 10 minutes.
  static const radioStatsKept = 2000;

  /// Stores one reading of the radio's receiver figures.
  Future<void> saveRadioStats(String radioKey, RadioStats stats) =>
      _db.transaction(() async {
        await _db
            .into(_db.radioStatsSamples)
            .insert(
              RadioStatsSamplesCompanion.insert(
                radioKey: radioKey,
                at: _clock().millisecondsSinceEpoch,
                noiseFloor: stats.noiseFloor,
                lastRssi: stats.lastRssi,
                lastSnr: stats.lastSnr,
                txAirSeconds: stats.txAirSeconds,
                rxAirSeconds: stats.rxAirSeconds,
              ),
            );
        await _db.customStatement(
          'DELETE FROM radio_stats_samples WHERE radio_key = ? '
          'AND id NOT IN (SELECT id FROM radio_stats_samples '
          'WHERE radio_key = ? ORDER BY id DESC LIMIT ?)',
          [radioKey, radioKey, radioStatsKept],
        );
      });

  /// A radio's receiver history, oldest first.
  Stream<List<RadioStatsSample>> watchRadioStats(String radioKey) =>
      (_db.select(_db.radioStatsSamples)
            ..where((t) => t.radioKey.equals(radioKey))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  /// When the newest receiver sample was taken, or null if none.
  Future<DateTime?> lastRadioStatsAt(String radioKey) async {
    final row =
        await (_db.select(_db.radioStatsSamples)
              ..where((t) => t.radioKey.equals(radioKey))
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : DateTime.fromMillisecondsSinceEpoch(row.at);
  }

  /// Forgets a radio's receiver history.
  Future<void> clearRadioStats(String radioKey) => (_db.delete(
    _db.radioStatsSamples,
  )..where((t) => t.radioKey.equals(radioKey))).go();
}
