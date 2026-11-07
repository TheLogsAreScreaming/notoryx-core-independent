import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/quick_messages.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => db = MeshDatabase.inMemory());
  tearDown(() => db.close());

  test('starts with the default list', () async {
    final c = container();
    expect(await c.read(quickMessagesProvider.future), defaultQuickMessages);
  });

  test('add, change, move and remove are saved', () async {
    final c = container();
    await c.read(quickMessagesProvider.future);
    final quick = c.read(quickMessagesProvider.notifier);
    await quick.reset();
    await quick.add('  At the trailhead ');
    await quick.add('OK'); // already there
    await quick.add('   '); // blank
    expect(c.read(quickMessagesProvider).value!.last, 'At the trailhead');
    expect(c.read(quickMessagesProvider).value, hasLength(8));

    await quick.edit(0, 'OK 👍');
    await quick.move(7, 0);
    await quick.remove(1);
    final expected = ['At the trailhead', ...defaultQuickMessages.skip(1)];
    expect(c.read(quickMessagesProvider).value, expected);

    // A fresh start reads the saved list back.
    final again = container();
    expect(await again.read(quickMessagesProvider.future), expected);
  });

  test('changing a message to blank removes it', () async {
    final c = container();
    await c.read(quickMessagesProvider.future);
    await c.read(quickMessagesProvider.notifier).edit(0, ' ');
    expect(c.read(quickMessagesProvider).value, defaultQuickMessages.skip(1));
  });

  test('moving down lands where it was dropped', () async {
    final c = container();
    await c.read(quickMessagesProvider.future);
    await c.read(quickMessagesProvider.notifier).move(0, 2);
    expect(c.read(quickMessagesProvider).value!.take(3), [
      'On my way',
      'Arrived safe',
      'OK',
    ]);
  });

  test('an unreadable saved list falls back to the defaults', () async {
    await MeshStore(db).saveSetting(quickMessagesSetting, '{oops');
    expect(
      await container().read(quickMessagesProvider.future),
      defaultQuickMessages,
    );
    await MeshStore(db).saveSetting(quickMessagesSetting, '{"a": 1}');
    expect(
      await container().read(quickMessagesProvider.future),
      defaultQuickMessages,
    );
  });

  group('drafts', () {
    test('are kept per radio and thread, and blank text forgets', () async {
      final store = MeshStore(db);
      await store.saveDraft('r1', 'c:1', 'half a thought');
      await store.saveDraft('r1', 'd:ab', 'hello');
      await store.saveDraft('r2', 'c:1', 'other radio');
      expect(await store.draft('r1', 'c:1'), 'half a thought');
      expect(await store.watchDrafts('r1').first, {
        'c:1': 'half a thought',
        'd:ab': 'hello',
      });

      await store.saveDraft('r1', 'c:1', '  ');
      expect(await store.draft('r1', 'c:1'), isNull);
      expect(await store.watchDrafts('r1').first, {'d:ab': 'hello'});
      expect(await store.watchDrafts('r2').first, {'c:1': 'other radio'});
    });
  });
}
