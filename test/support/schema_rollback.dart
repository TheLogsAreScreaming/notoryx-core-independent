import 'package:notoryx_core/data/data.dart';

/// Turns a current database back into an older schema [version], so tests
/// can check the upgrade path from it. Each step undoes what that version
/// added, newest first.
Future<void> rollBackTo(MeshDatabase db, int version) async {
  final steps = <int, List<String>>{
    9: ['DROP TABLE track_points', 'DROP TABLE tracks'],
    8: ['DROP TABLE radio_stats_samples'],
    7: ['DROP TABLE telemetry_samples'],
    6: [
      'ALTER TABLE messages DROP COLUMN text_type',
      'ALTER TABLE messages DROP COLUMN author_prefix',
    ],
    5: ['DROP TABLE discovered'],
    4: ['DROP TABLE thread_states'],
    3: ['DROP TABLE settings'],
    2: ['ALTER TABLE messages DROP COLUMN attempts'],
  };
  for (var v = db.schemaVersion; v > version; v--) {
    for (final sql in steps[v] ?? const <String>[]) {
      await db.customStatement(sql);
    }
  }
  await db.customStatement('PRAGMA user_version = $version');
}
