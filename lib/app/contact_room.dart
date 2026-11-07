/// How full the radio's contact table is, and which contacts can go to
/// make room. The radio stops adding nodes it hears once the table is full.
library;

import '../data/data.dart';

/// How full the table is.
enum ContactLevel { ok, nearlyFull, full }

/// The contact table's fill.
final class ContactMeter {
  const ContactMeter(this.count, this.max);

  final int count;
  final int max;

  double get fraction => max == 0 ? 0 : (count / max).clamp(0, 1).toDouble();

  int get free => max - count < 0 ? 0 : max - count;

  ContactLevel get level => count >= max
      ? ContactLevel.full
      : count >= (max * 0.9).ceil()
      ? ContactLevel.nearlyFull
      : ContactLevel.ok;
}

bool isFavourite(Contact c) => c.flags & 1 == 1;

/// Contacts that could be removed, least useful first: favourites are never
/// offered, and the ones heard longest ago (or never) come first.
List<Contact> removalCandidates(List<Contact> contacts) {
  final list = contacts.where((c) => !isFavourite(c)).toList()
    ..sort((a, b) {
      final byAdvert = a.lastAdvert.compareTo(b.lastAdvert);
      return byAdvert != 0 ? byAdvert : a.name.compareTo(b.name);
    });
  return list;
}

/// "heard 3 days ago" for a contact's last advert (Unix seconds, by the
/// node's clock); "never heard" for zero.
String lastHeard(int lastAdvert, DateTime now) {
  if (lastAdvert <= 0) return 'never heard';
  final ago = now.difference(
    DateTime.fromMillisecondsSinceEpoch(lastAdvert * 1000),
  );
  if (ago.isNegative || ago.inHours < 1) return 'heard in the last hour';
  if (ago.inDays < 1) return 'heard ${ago.inHours} h ago';
  if (ago.inDays == 1) return 'heard yesterday';
  if (ago.inDays < 60) return 'heard ${ago.inDays} days ago';
  return 'heard ${ago.inDays ~/ 30} months ago';
}
