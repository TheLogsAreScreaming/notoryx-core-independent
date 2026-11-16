/// Which chats send their messages SMAZ-compressed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'connection.dart';

const _prefix = 'smaz.';

/// Thread ids with compression on.
final compressedThreadsProvider = StreamProvider<Set<String>>(
  (ref) => ref
      .watch(storeProvider)
      .watchSettingsWithPrefix(_prefix)
      .map(
        (rows) => {
          for (final e in rows.entries)
            if (e.value == 'on') e.key,
        },
      ),
);

/// Turns compression on or off for [thread].
Future<void> setCompressed(MeshStore store, String thread, bool on) => on
    ? store.saveSetting(smazSetting(thread), 'on')
    : store.removeSetting(smazSetting(thread));
