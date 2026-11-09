/// Backing up and restoring the whole app database.
///
/// A backup is the SQLite database (taken with `VACUUM INTO`, so it is
/// consistent while the app runs), gzipped, behind a small JSON header
/// that says which schema and app made it. That plain payload is then
/// sealed with a password by `backup_crypto.dart`.
///
/// Restoring is all or nothing: the backup is written to a staging file,
/// upgraded there to this app's schema, and only then copied over every
/// table inside one transaction. A backup from a newer schema is refused.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'backup_crypto.dart';
import 'database.dart';

/// What a backup says about itself.
typedef BackupInfo = ({
  int schemaVersion,
  String appVersion,
  DateTime exportedAt,
});

/// What a restore brought back.
typedef RestoreSummary = ({int radios, int messages, int contacts});

/// The plain (unsealed) payload: header, then the gzipped database.
Future<Uint8List> backupPayload(
  MeshDatabase db, {
  required Directory temp,
  required String appVersion,
  DateTime? now,
  String? key,
}) async {
  final file = File(
    '${temp.path}/notoryx-backup-${DateTime.now().microsecondsSinceEpoch}.sqlite',
  );
  try {
    await db.customStatement('VACUUM INTO ?', [file.path]);
    // The copy inherits this phone's key. A backup must restore on another
    // phone, so it is plain here and sealed with the password afterwards.
    if (key != null) {
      final copy = sqlite3.open(file.path);
      try {
        copy
          ..execute("PRAGMA key = '$key'")
          ..execute("PRAGMA rekey = ''");
      } finally {
        copy.close();
      }
    }
    final sqlite = await file.readAsBytes();
    final header = utf8.encode(
      jsonEncode({
        'format': 1,
        'schemaVersion': db.schemaVersion,
        'appVersion': appVersion,
        'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      }),
    );
    return (BytesBuilder()
          ..add(_u32(header.length))
          ..add(header)
          ..add(gzip.encode(sqlite)))
        .toBytes();
  } finally {
    if (await file.exists()) await file.delete();
  }
}

/// Splits a plain payload into its header and database bytes. Throws
/// [BackupException] when it doesn't hold a backup this app can restore.
({BackupInfo info, Uint8List sqlite}) readPayload(
  List<int> payload, {
  required int currentSchema,
}) {
  try {
    final data = ByteData.sublistView(Uint8List.fromList(payload));
    final length = data.getUint32(0);
    final json = jsonDecode(
      utf8.decode(payload.sublist(4, 4 + length)),
    ) as Map<String, Object?>;
    final info = (
      schemaVersion: json['schemaVersion']! as int,
      appVersion: json['appVersion']! as String,
      exportedAt: DateTime.parse(json['exportedAt']! as String),
    );
    if (info.schemaVersion > currentSchema) {
      throw const BackupException(
        'This backup was made by a newer version of the app. Update it first.',
      );
    }
    final sqlite = Uint8List.fromList(gzip.decode(payload.sublist(4 + length)));
    if (sqlite.length < 16 ||
        ascii.decode(sqlite.sublist(0, 15), allowInvalid: true) !=
            'SQLite format 3') {
      throw const BackupException('That backup file is damaged.');
    }
    return (info: info, sqlite: sqlite);
  } on BackupException {
    rethrow;
  } on Object {
    throw const BackupException('That backup file is damaged.');
  }
}

/// Replaces everything in [live] with the database in [sqlite].
Future<RestoreSummary> restoreDatabase(
  MeshDatabase live,
  Uint8List sqlite, {
  required Directory temp,
}) async {
  final staging = File(
    '${temp.path}/notoryx-restore-${DateTime.now().microsecondsSinceEpoch}.sqlite',
  );
  await staging.writeAsBytes(sqlite, flush: true);
  try {
    // Opening it runs the upgrades, so its tables match this app's.
    final upgraded = MeshDatabase(NativeDatabase(staging));
    try {
      await upgraded.customSelect('SELECT 1').get();
    } finally {
      await upgraded.close();
    }

    final tables = live.allTables.toList();
    // An empty key, or it would be read with the live database's key.
    await live.customStatement("ATTACH DATABASE ? AS restore KEY ''", [
      staging.path,
    ]);
    try {
      await live.transaction(() async {
        // Children before parents, so foreign keys hold throughout.
        for (final t in tables.reversed) {
          await live.customUpdate(
            'DELETE FROM main.${t.actualTableName}',
            updates: {t},
            updateKind: UpdateKind.delete,
          );
        }
        for (final t in tables) {
          final columns = [
            for (final row
                in await live
                    .customSelect(
                      'PRAGMA main.table_info(${t.actualTableName})',
                    )
                    .get())
              '"${row.read<String>('name')}"',
          ].join(', ');
          await live.customUpdate(
            'INSERT INTO main.${t.actualTableName} ($columns) '
            'SELECT $columns FROM restore.${t.actualTableName}',
            updates: {t},
            updateKind: UpdateKind.insert,
          );
        }
      });
    } finally {
      await live.customStatement('DETACH DATABASE restore');
    }
    Future<int> count(String table) async =>
        (await live
                .customSelect('SELECT COUNT(*) AS n FROM $table')
                .getSingle())
            .read<int>('n');
    return (
      radios: await count('radios'),
      messages: await count('messages'),
      contacts: await count('contacts'),
    );
  } finally {
    if (await staging.exists()) await staging.delete();
  }
}

List<int> _u32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];
