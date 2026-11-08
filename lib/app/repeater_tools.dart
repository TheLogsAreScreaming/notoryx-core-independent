/// Helpers for the repeater console's one-tap tools.
library;

import '../data/data.dart';

/// A node a repeater has heard directly.
typedef RepeaterNeighbor = ({String prefix, int secondsAgo, double snr});

final _neighborLine = RegExp(r'^([0-9A-Fa-f]{2,64}):(\d+):(-?\d+)$');

/// Reads the repeater's reply to `neighbors`: one `PREFIX:SECONDS:SNR` per
/// line, SNR in quarter-dB. Returns null when [reply] isn't that reply.
/// An empty list means it has heard nobody yet.
List<RepeaterNeighbor>? parseNeighbors(String reply) {
  final text = reply.replaceFirst(RegExp(r'^\s*>\s*'), '').trim();
  if (text == '-none-') return const [];
  final out = <RepeaterNeighbor>[];
  for (final line in text.split('\n')) {
    final m = _neighborLine.firstMatch(line.trim());
    if (m == null) return null;
    out.add((
      prefix: m[1]!.toLowerCase(),
      secondsAgo: int.parse(m[2]!),
      snr: int.parse(m[3]!) / 4,
    ));
  }
  return out.isEmpty ? null : out;
}

/// The newest neighbor list among console [lines], oldest first as stored.
List<RepeaterNeighbor>? latestNeighbors(List<Message> lines) {
  for (final m in lines.reversed) {
    if (m.outgoing) continue;
    final parsed = parseNeighbors(m.body);
    if (parsed != null) return parsed;
  }
  return null;
}

/// What a contact is allowed to do on a repeater or room server.
enum ServerPermission {
  remove(0, 'No access (remove)'),
  readOnly(1, 'Read only'),
  readWrite(2, 'Read and write'),
  admin(3, 'Admin');

  const ServerPermission(this.value, this.label);

  final int value;
  final String label;
}

/// The console command that sets [publicKeyHex]'s [permission].
String setPermissionCommand(String publicKeyHex, ServerPermission permission) =>
    'setperm $publicKeyHex ${permission.value}';
