import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('old channel messages go; direct and recent ones stay', () async {
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    final now = DateTime(2026, 11, 8);
    final store = MeshStore(db, clock: () => now);
    await db.customStatement(
      "INSERT INTO radios (public_key, name, last_connected_at) "
      "VALUES ('r', 'R', 0)",
    );
    Future<void> add(String thread, Duration age) => db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            radioKey: 'r',
            kind: MessageKind.values.first,
            thread: thread,
            outgoing: false,
            body: thread,
            sentAt: 0,
            storedAt: now.subtract(age).millisecondsSinceEpoch,
            status: MessageStatus.values.first,
          ),
        );
    await add('c:1', const Duration(days: 40));
    await add('c:1', const Duration(days: 2));
    await add('d:ab', const Duration(days: 400));

    expect(await store.deleteOldChannelMessages(const Duration(days: 30)), 1);
    expect(await db.select(db.messages).get(), hasLength(2));
  });
}
