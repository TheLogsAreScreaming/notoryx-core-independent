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
        row = _incoming(
          radioKey,
          kind: MessageKind.direct,
          thread: Threads.direct(contact?.publicKey ?? prefix),
          body: frame.text,
          sentAt: frame.timestamp,
          pathLength: frame.pathLength,
          snr: frame.snr,
          dedupeKey: 'd:$prefix:${frame.timestamp}:${frame.text}',
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
  );

  /// Stores a message about to be sent, as pending. Returns its id.
  Future<int> saveOutgoing(
    String radioKey, {
    required String thread,
    required String body,
    required int sentAt,
  }) => _db
      .into(_db.messages)
      .insert(
        MessagesCompanion.insert(
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
      ..where(_db.messages.radioKey.equals(radioKey))
      ..groupBy([_db.messages.thread]);
    return (_db.select(_db.messages)
          ..where((m) => m.id.isInQuery(newestIds))
          ..orderBy([(m) => OrderingTerm.desc(m.id)]))
        .watch();
  }

  // Unread and muting

  /// Unread incoming messages per thread; threads with none are left out.
  Stream<Map<String, int>> watchUnreadCounts(String radioKey) => _db
      .customSelect(
        'SELECT m.thread AS thread, COUNT(*) AS unread FROM messages m '
        'LEFT JOIN thread_states t '
        'ON t.radio_key = m.radio_key AND t.thread = m.thread '
        'WHERE m.radio_key = ? AND m.outgoing = 0 '
        'AND m.id > COALESCE(t.last_read_id, 0) '
        'GROUP BY m.thread',
        variables: [Variable.withString(radioKey)],
        readsFrom: {_db.messages, _db.threadStates},
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

  /// A conversation as it is now, oldest first.
  Future<List<Message>> threadSnapshot(String radioKey, String thread) =>
      (_db.select(_db.messages)
            ..where(
              (m) => m.radioKey.equals(radioKey) & m.thread.equals(thread),
            )
            ..orderBy([(m) => OrderingTerm.asc(m.id)]))
          .get();

  /// A conversation, oldest first.
  Stream<List<Message>> watchThread(String radioKey, String thread) =>
      (_db.select(_db.messages)
            ..where(
              (m) => m.radioKey.equals(radioKey) & m.thread.equals(thread),
            )
            ..orderBy([(m) => OrderingTerm.asc(m.id)]))
          .watch();
}
