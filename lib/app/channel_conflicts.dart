import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What one channel slot holds: name and 16-byte secret.
typedef SlotState = ({int slot, String name, Uint8List secret});

bool _sameSlot(SlotState a, SlotState b) {
  if (a.name != b.name || a.secret.length != b.secret.length) return false;
  for (var i = 0; i < a.secret.length; i++) {
    if (a.secret[i] != b.secret[i]) return false;
  }
  return true;
}

/// A slot the radio changed or emptied behind the app's back.
typedef SlotMismatch = ({SlotState mine, SlotState? radio});

/// Lines up the app's copy of a radio's channels ([mine], plus [waiting]
/// copies the user hasn't decided on) with what the radio reported now.
/// Slots the app has never seen are new channels, not mismatches; slots at
/// or above [count] weren't asked for.
List<SlotMismatch> compareSlots({
  required Iterable<SlotState> mine,
  required Iterable<SlotState> radio,
  required int count,
  Iterable<SlotState> waiting = const [],
}) {
  final ours = <int, SlotState>{for (final s in mine) s.slot: s};
  for (final s in waiting) {
    ours[s.slot] = s;
  }
  final theirs = <int, SlotState>{
    for (final s in radio)
      if (s.name.isNotEmpty || s.secret.any((b) => b != 0)) s.slot: s,
  };
  final slots = ours.keys.where((s) => s < count).toList()..sort();
  return [
    for (final s in slots)
      if (theirs[s] == null || !_sameSlot(ours[s]!, theirs[s]!))
        (mine: ours[s]!, radio: theirs[s]),
  ];
}

/// The settings key holding a radio's undecided mismatches.
String mismatchKey(String radioKey) => 'channel_mismatch_v1:$radioKey';

String encodeMismatches(Iterable<SlotMismatch> list) => jsonEncode([
  for (final m in list)
    {
      'slot': m.mine.slot,
      'name': m.mine.name,
      'secret': base64Encode(m.mine.secret),
      if (m.radio case final r?) 'radioName': r.name,
      if (m.radio case final r?) 'radioSecret': base64Encode(r.secret),
    },
]);

List<SlotMismatch> decodeMismatches(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    final out = <SlotMismatch>[];
    for (final e in list) {
      if (e is! Map) continue;
      final slot = e['slot'], name = e['name'], secret = e['secret'];
      if (slot is! int || name is! String || secret is! String) continue;
      final rName = e['radioName'], rSecret = e['radioSecret'];
      out.add((
        mine: (slot: slot, name: name, secret: base64Decode(secret)),
        radio: rName is String && rSecret is String
            ? (slot: slot, name: rName, secret: base64Decode(rSecret))
            : null,
      ));
    }
    return out;
  } on FormatException {
    return const [];
  }
}

/// Tells two secrets apart on screen without showing them.
String secretTag(Uint8List secret) {
  final d = sha256.convert(secret).bytes;
  return [for (final b in d.take(4)) b.toRadixString(16).padLeft(2, '0')]
      .join()
      .replaceRange(4, 4, ' ');
}
