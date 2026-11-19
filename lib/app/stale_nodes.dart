/// Marking contacts and repeaters that haven't been heard for a while, so
/// a node that has gone quiet stands out in the lists and on the map.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../l10n/l10n.dart';
import 'connection.dart';

/// Setting key; the chosen [StaleAfter]'s name.
const staleAfterKey = 'view.staleAfter';

/// How long a node can go unheard before it's marked stale.
enum StaleAfter {
  off(null),
  hour(Duration(hours: 1)),
  sixHours(Duration(hours: 6)),
  day(Duration(hours: 24)),
  threeDays(Duration(days: 3)),
  week(Duration(days: 7));

  const StaleAfter(this.after);

  /// Null when nothing is ever marked stale.
  final Duration? after;

  /// The choice in the app's language.
  String label(AppLocalizations l10n) => switch (this) {
    off => l10n.staleOff,
    hour => l10n.staleHour,
    sixHours => l10n.staleSixHours,
    day => l10n.staleDay,
    threeDays => l10n.staleThreeDays,
    week => l10n.staleWeek,
  };

  static const fallback = StaleAfter.day;

  /// The saved choice, or the default for anything unknown.
  static StaleAfter parse(String? raw) =>
      StaleAfter.values.asNameMap()[raw] ?? fallback;
}

/// Times before this can't be real last-heard times: a node whose clock was
/// never set reports 1970 or thereabouts.
final earliestPlausible = DateTime.utc(2020);

/// How far ahead of the phone a node's clock may run before its times are
/// not believed.
const futureSlack = Duration(days: 1);

/// [lastHeard] if it could be a real time at [now], else null: unset (null
/// or the 1970 epoch), before 2020, or more than a day in the future.
DateTime? plausibleHeard(DateTime? lastHeard, DateTime now) {
  if (lastHeard == null) return null;
  if (lastHeard.isBefore(earliestPlausible)) return null;
  if (lastHeard.isAfter(now.add(futureSlack))) return null;
  return lastHeard;
}

/// Whether a node last heard at [lastHeard] counts as stale at [now].
///
/// A node whose last-heard time is unknown is never stale: never heard
/// (null), or a time [plausibleHeard] rejects. There is no age to judge.
/// With [after] null (the setting is off) nothing is stale. A time slightly
/// in the future, from a node whose clock runs fast, is not stale either.
bool isStale(DateTime? lastHeard, DateTime now, Duration? after) {
  final heard = plausibleHeard(lastHeard, now);
  if (heard == null || after == null) return false;
  return now.difference(heard) >= after;
}

/// A node's last advert (Unix seconds, by its own clock) as a time, or null
/// when it has never advertised.
DateTime? advertTime(int lastAdvert) => lastAdvert <= 0
    ? null
    : DateTime.fromMillisecondsSinceEpoch(lastAdvert * 1000);

/// The stale-after setting. Shared by every radio, since it's how you want
/// to look at the mesh, not a radio setting.
final staleAfterProvider = StreamProvider<StaleAfter>(
  (ref) => ref
      .watch(storeProvider)
      .watchSettingsWithPrefix(staleAfterKey)
      .map((m) => StaleAfter.parse(m[''])),
);

Future<void> setStaleAfter(MeshStore store, StaleAfter choice) =>
    store.saveSetting(staleAfterKey, choice.name);
