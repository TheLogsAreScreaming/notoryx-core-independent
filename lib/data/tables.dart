import 'package:drift/drift.dart';

/// Radios this phone has connected to. Everything else is stored per radio,
/// because each radio has its own contacts, channels and message queue.
class Radios extends Table {
  /// The radio's public key, hex.
  TextColumn get publicKey => text()();
  TextColumn get name => text()();
  IntColumn get lastConnectedAt => integer()();

  /// Newest contact `lastModified` seen, so the next sync only fetches
  /// changes. Zero means fetch everything.
  IntColumn get contactsSince => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {publicKey};
}

/// A copy of each radio's contact table.
class Contacts extends Table {
  TextColumn get radioKey => text().references(Radios, #publicKey)();
  TextColumn get publicKey => text()();
  TextColumn get name => text()();

  /// `NodeType.value`: chat, repeater, room or sensor.
  IntColumn get type => integer()();
  IntColumn get flags => integer()();

  /// Encoded route length, 0xFF for none.
  IntColumn get outPathLength => integer()();
  BlobColumn get outPath => blob()();
  IntColumn get lastAdvert => integer()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get lastModified => integer()();

  @override
  Set<Column> get primaryKey => {radioKey, publicKey};
}

/// A copy of each radio's channel slots. Empty slots aren't stored.
class Channels extends Table {
  TextColumn get radioKey => text().references(Radios, #publicKey)();
  IntColumn get slot => integer()();
  TextColumn get name => text()();
  BlobColumn get secret => blob()();

  @override
  Set<Column> get primaryKey => {radioKey, slot};
}

/// Where a message belongs.
enum MessageKind { direct, channel }

/// Where an outgoing message has got to. Incoming ones are [received].
enum MessageStatus { pending, sent, delivered, failed, received }

/// Direct and channel messages, both directions.
@TableIndex(name: 'messages_by_thread', columns: {#radioKey, #thread, #id})
@TableIndex(name: 'messages_by_ack', columns: {#radioKey, #ackCode})
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get radioKey => text().references(Radios, #publicKey)();
  IntColumn get kind => intEnum<MessageKind>()();

  /// The conversation, built by `Threads`: `d:` plus the contact key (or key
  /// prefix) in hex, or `c:` plus the channel slot.
  TextColumn get thread => text()();

  BoolColumn get outgoing => boolean()();
  TextColumn get body => text()();

  /// Channel messages: the name the sender put before the text.
  TextColumn get senderName => text().nullable()();

  /// Sender's clock, Unix seconds.
  IntColumn get sentAt => integer()();

  /// This phone's clock when stored, Unix milliseconds.
  IntColumn get storedAt => integer()();

  IntColumn get status => intEnum<MessageStatus>()();

  /// Outgoing direct messages: how many times it has been sent so far.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Outgoing direct messages: the code the delivery ack will carry.
  IntColumn get ackCode => integer().nullable()();
  BoolColumn get flooded => boolean().nullable()();
  IntColumn get pathLength => integer().nullable()();
  RealColumn get snr => real().nullable()();

  /// Incoming only: identifies a message so a repeat delivery is dropped.
  TextColumn get dedupeKey => text().nullable().unique()();
}

/// Small app settings, one value per key, such as the last radio used.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Per-conversation state the person controls: what they have read, and
/// whether new messages there notify.
class ThreadStates extends Table {
  TextColumn get radioKey => text().references(Radios, #publicKey)();
  TextColumn get thread => text()();

  /// Newest message id seen; incoming messages above it are unread.
  IntColumn get lastReadId => integer().withDefault(const Constant(0))();

  BoolColumn get muted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {radioKey, thread};
}

/// Nodes the radio heard advertising but did not add as contacts (manual
/// add is on, the node was too many hops away, or the contact table is
/// full). They can be added from the Contacts tab.
class Discovered extends Table {
  TextColumn get radioKey => text().references(Radios, #publicKey)();
  TextColumn get publicKey => text()();
  TextColumn get name => text()();
  IntColumn get type => integer()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  /// When the node last advertised, by its own clock.
  IntColumn get lastAdvert => integer()();

  /// When this phone heard it, Unix milliseconds.
  IntColumn get heardAt => integer()();

  @override
  Set<Column> get primaryKey => {radioKey, publicKey};
}
