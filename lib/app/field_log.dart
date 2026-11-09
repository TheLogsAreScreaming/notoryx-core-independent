/// The trip brief, and the Field Log of everything sent and received.
library;

import 'dart:convert';

import '../data/data.dart';

const tripBriefSetting = 'trip_brief';

/// What someone is planning, kept so it can be sent again or edited.
final class TripBrief {
  const TripBrief({
    this.where = '',
    this.backBy = '',
    this.people = '',
    this.notes = '',
  });

  factory TripBrief.fromJson(String? raw) {
    if (raw == null) return const TripBrief();
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      String read(String k) => m[k] is String ? m[k]! as String : '';
      return TripBrief(
        where: read('where'),
        backBy: read('backBy'),
        people: read('people'),
        notes: read('notes'),
      );
    } on Object {
      return const TripBrief();
    }
  }

  final String where;
  final String backBy;
  final String people;
  final String notes;

  String toJson() => jsonEncode({
    'where': where,
    'backBy': backBy,
    'people': people,
    'notes': notes,
  });

  /// The one message that goes out. Empty parts are left out.
  String get text {
    String part(String label, String v) =>
        v.trim().isEmpty ? '' : '$label ${v.trim()}. ';
    return ('Trip brief: ${part('Going to', where)}${part('Back by', backBy)}'
            '${part('People:', people)}${notes.trim()}')
        .trim();
  }

  /// Whether there's anything to send.
  bool get isEmpty =>
      where.trim().isEmpty &&
      backBy.trim().isEmpty &&
      people.trim().isEmpty &&
      notes.trim().isEmpty;

  /// How long [text] is on the air, in bytes.
  int get byteLength => utf8.encode(text).length;
}

/// How far back the Field Log looks.
enum FieldLogRange {
  today('Today', Duration(hours: 24)),
  week('7 days', Duration(days: 7)),
  all('All', null);

  const FieldLogRange(this.label, this.span);

  final String label;
  final Duration? span;
}

/// One message as a line of the log, for reading or copying.
String fieldLogLine(Message m, String chat) {
  final t = DateTime.fromMillisecondsSinceEpoch(m.storedAt).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  final at =
      '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  if (m.outgoing) return '$at  Sent to $chat: ${m.body}';
  final sender = m.kind == MessageKind.channel && m.senderName != null
      ? '${m.senderName} on $chat'
      : chat;
  return '$at  From $sender: ${m.body}';
}
