import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/stale_nodes.dart';
import 'package:notoryx_core/l10n/l10n.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);
  const day = Duration(hours: 24);

  group('isStale', () {
    test('a node never heard is never stale', () {
      expect(isStale(null, now, day), isFalse);
      expect(isStale(null, now, const Duration(seconds: 1)), isFalse);
    });

    test('nothing is stale when the setting is off', () {
      expect(
        isStale(now.subtract(const Duration(days: 9)), now, null),
        isFalse,
      );
    });

    test('stale from exactly the threshold on', () {
      expect(isStale(now.subtract(day), now, day), isTrue);
      expect(
        isStale(now.subtract(day - const Duration(seconds: 1)), now, day),
        isFalse,
      );
      expect(isStale(now.subtract(const Duration(days: 30)), now, day), isTrue);
    });

    test('a time ahead of now, from a fast clock, is not stale', () {
      expect(isStale(now.add(const Duration(hours: 5)), now, day), isFalse);
    });

    test('an unset or impossible time is unknown, so never stale', () {
      // The 1970 epoch, from a node whose clock was never set.
      expect(isStale(DateTime.utc(1970), now, day), isFalse);
      expect(isStale(advertTime(1), now, day), isFalse);
      // Before 2020.
      expect(isStale(DateTime.utc(2019, 12, 31, 23), now, day), isFalse);
      expect(
        isStale(DateTime.utc(2017, 6), now, StaleAfter.hour.after),
        isFalse,
      );
      // More than a day in the future.
      expect(isStale(now.add(const Duration(days: 2)), now, day), isFalse);
      expect(isStale(DateTime.utc(2031), now, day), isFalse);
    });

    test('a normal time is judged as before', () {
      expect(isStale(DateTime.utc(2020, 1, 2), now, day), isTrue);
      expect(isStale(now.subtract(const Duration(days: 3)), now, day), isTrue);
      expect(
        isStale(now.subtract(const Duration(hours: 3)), now, day),
        isFalse,
      );
    });

    test('each choice uses its own threshold', () {
      final heard = now.subtract(const Duration(hours: 7));
      expect(isStale(heard, now, StaleAfter.hour.after), isTrue);
      expect(isStale(heard, now, StaleAfter.sixHours.after), isTrue);
      expect(isStale(heard, now, StaleAfter.day.after), isFalse);
      expect(isStale(heard, now, StaleAfter.week.after), isFalse);
      expect(isStale(heard, now, StaleAfter.off.after), isFalse);
    });
  });

  test('advertTime: zero or less means never', () {
    expect(advertTime(0), isNull);
    expect(advertTime(-5), isNull);
    expect(
      advertTime(1763467200),
      DateTime.fromMillisecondsSinceEpoch(1763467200 * 1000),
    );
  });

  test('plausibleHeard keeps real times and drops the rest', () {
    expect(plausibleHeard(null, now), isNull);
    expect(plausibleHeard(DateTime.utc(1970), now), isNull);
    expect(plausibleHeard(DateTime.utc(2019, 12, 31), now), isNull);
    expect(plausibleHeard(DateTime.utc(2020), now), DateTime.utc(2020));
    final soon = now.add(const Duration(hours: 23));
    expect(plausibleHeard(soon, now), soon);
    expect(plausibleHeard(now.add(const Duration(hours: 25)), now), isNull);
    final normal = now.subtract(const Duration(days: 4));
    expect(plausibleHeard(normal, now), normal);
  });

  test('the setting defaults to 24 hours and reads back by name', () {
    expect(StaleAfter.parse(null), StaleAfter.day);
    expect(StaleAfter.parse('nonsense'), StaleAfter.day);
    for (final c in StaleAfter.values) {
      expect(StaleAfter.parse(c.name), c);
    }
  });

  test('the choices are Off, 1 h, 6 h, 24 h, 3 days, 7 days', () {
    expect(StaleAfter.values.map((c) => c.after), [
      null,
      const Duration(hours: 1),
      const Duration(hours: 6),
      const Duration(hours: 24),
      const Duration(days: 3),
      const Duration(days: 7),
    ]);
  });

  test('every language labels every choice and the badge', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final labels = {for (final c in StaleAfter.values) c.label(l10n)};
      expect(labels, hasLength(StaleAfter.values.length), reason: '$locale');
      expect(l10n.staleBadge('X'), contains('X'), reason: '$locale');
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.staleBadge('3 days ago'), 'stale · 3 days ago');
  });
}
