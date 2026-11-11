import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'db_encryption.dart';
import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// Where the app's database lives.
Future<File> meshDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'notoryx.sqlite'));
}

/// Whether this launch found an encrypted database with no key and set it
/// aside.
bool databaseSetAside = false;

/// The app's on-device database.
@DriftDatabase(
  tables: [
    Radios,
    Contacts,
    Channels,
    Messages,
    Settings,
    ThreadStates,
    Discovered,
    TelemetrySamples,
    RadioStatsSamples,
    Tracks,
    TrackPoints,
  ],
)
class MeshDatabase extends _$MeshDatabase {
  MeshDatabase(super.executor);

  /// Opens the database in the app's support folder, on a background isolate.
  factory MeshDatabase.open({DbKeyStore keys = const SecureDbKeyStore()}) =>
      MeshDatabase(
        LazyDatabase(() async {
          final file = await meshDatabaseFile();
          final key = await prepareDatabase(
            file,
            keys,
            onUnreadable: (_) => databaseSetAside = true,
          );
          return NativeDatabase.createInBackground(
            file,
            setup: key == null
                ? null
                : (raw) => raw.execute("PRAGMA key = '$key'"),
          );
        }),
      );

  /// An empty database in memory, for tests.
  factory MeshDatabase.inMemory() => MeshDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // 2: messages remember how many times they were sent.
      if (from < 2) await m.addColumn(messages, messages.attempts);
      // 3: settings, starting with the last radio for reconnecting.
      if (from < 3) await m.createTable(settings);
      // 4: unread tracking and muting. Everything already stored counts as
      // read, so an upgrade doesn't light up every chat.
      if (from < 4) {
        await m.createTable(threadStates);
        await customStatement(
          'INSERT INTO thread_states (radio_key, thread, last_read_id, muted) '
          'SELECT radio_key, thread, MAX(id), 0 FROM messages '
          'GROUP BY radio_key, thread',
        );
      }
      // 5: nodes heard but not added get their own table. Earlier builds
      // stored them as contacts, so the next connect re-downloads the whole
      // contact list, which drops them again.
      if (from < 5) {
        await m.createTable(discovered);
        await customStatement('UPDATE radios SET contacts_since = 0');
      }
      // 6: room post authors, and console text kept apart from chat.
      if (from < 6) {
        await m.addColumn(messages, messages.textType);
        await m.addColumn(messages, messages.authorPrefix);
      }
      // 7: telemetry history.
      if (from < 7) await m.createTable(telemetrySamples);
      if (from < 8) {
        await m.createTable(radioStatsSamples);
        await m.createIndex(radioStatsByRadio);
      }
      // 9: track log.
      if (from < 9) {
        await m.createTable(tracks);
        await m.createTable(trackPoints);
        await m.createIndex(trackPointsByTrack);
      }
      // 10: the region a channel post was scoped to.
      if (from < 10) await m.addColumn(messages, messages.region);
      // 11: signatures on channel posts.
      if (from < 11) {
        await m.addColumn(messages, messages.signer);
        await m.addColumn(messages, messages.signatureValid);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
