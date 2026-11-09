/// Hiding channel posts that someone keeps repeating.
///
/// Off unless turned on. The first copies stay visible, and nothing that
/// could matter in an emergency is touched: SOS posts and messages that
/// mention you always show, so the repeating SOS can never be hidden.
/// Hidden posts stay stored, so turning the filter off brings them back.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'blocking.dart';
import 'connection.dart';

const spamFilterSetting = 'spam_filter';

/// How far back a post counts as a repeat.
const spamWindow = Duration(minutes: 30);

/// How many copies of a post stay visible within [spamWindow].
const spamCopiesShown = 2;

final _sosWord = RegExp(r'\bsos\b', caseSensitive: false);

/// Whether the filter is on.
final spamFilterProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(storeProvider)
      .watchSettingsWithPrefix(spamFilterSetting)
      .map((s) => s[''] == '1'),
);

/// Turns the filter on or off.
Future<void> setSpamFilter(MeshStore store, {required bool on}) => on
    ? store.saveSetting(spamFilterSetting, '1')
    : store.removeSetting(spamFilterSetting);

/// The ids of the posts in [oldestFirst] to hide as repeats. Posts with no
/// sender name can't be told apart, so they are never hidden.
Set<int> spamRepeats(Iterable<Message> oldestFirst, {String? myName}) {
  final seen = <String, List<int>>{};
  final hidden = <int>{};
  for (final m in oldestFirst) {
    final sender = m.senderName;
    if (m.outgoing || m.kind != MessageKind.channel || sender == null) {
      continue;
    }
    if (_sosWord.hasMatch(m.body) || mentions(m.body, myName)) continue;
    final text = m.body.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final times = seen.putIfAbsent('${m.thread}|$sender|$text', () => [])
      ..removeWhere((t) => m.storedAt - t > spamWindow.inMilliseconds);
    if (times.length >= spamCopiesShown) hidden.add(m.id);
    times.add(m.storedAt);
  }
  return hidden;
}
