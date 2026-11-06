import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// The app's on-device database.
@DriftDatabase(tables: [Radios, Contacts, Channels, Messages, Settings])
class MeshDatabase extends _$MeshDatabase {
  MeshDatabase(super.executor);

  /// Opens the database in the app's support folder, on a background isolate.
  factory MeshDatabase.open() => MeshDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(dir.path, 'notoryx.sqlite')),
      );
    }),
  );

  /// An empty database in memory, for tests.
  factory MeshDatabase.inMemory() => MeshDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // 2: messages remember how many times they were sent.
      if (from < 2) await m.addColumn(messages, messages.attempts);
      // 3: settings, starting with the last radio for reconnecting.
      if (from < 3) await m.createTable(settings);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
