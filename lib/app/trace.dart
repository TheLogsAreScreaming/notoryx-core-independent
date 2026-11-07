import 'dart:typed_data';

import '../data/data.dart';
import '../radio/radio.dart';

/// The hops a trace to a node visits: out along the radio's route, through
/// the node itself when it's a repeater or room server (they pass traces
/// on; people's radios don't), and back the same way to this radio.
typedef TracePlan = ({List<Uint8List> hops, int hashBytes});

/// Plans a round-trip trace to [contact], or null when there is nothing
/// to trace: no known route, a direct neighbour that doesn't pass traces
/// on, or a hash size the trace command can't carry.
TracePlan? planTrace(Contact contact) {
  if (contact.outPathLength == pathUnknown) return null;
  final hopCount = contact.outPathLength & 0x3F;
  final hashBytes = (contact.outPathLength >> 6) + 1;
  if (!const [1, 2, 4].contains(hashBytes)) return null;
  final out = [
    for (var i = 0; i < hopCount; i++)
      Uint8List.fromList(
        contact.outPath.sublist(i * hashBytes, (i + 1) * hashBytes),
      ),
  ];
  final type = NodeType.fromByte(contact.type);
  if (type == NodeType.repeater || type == NodeType.room) {
    out.add(
      Uint8List.fromList(fromHex(contact.publicKey).sublist(0, hashBytes)),
    );
  }
  if (out.isEmpty) return null;
  return (hops: [...out, ...out.reversed.skip(1)], hashBytes: hashBytes);
}

/// One leg of a trace: who sent, who heard, and how well.
typedef TraceLeg = ({String from, String to, double snr});

/// Names each leg of a returned [trace]. Hops are named after the contact
/// whose key starts with their hash, or shown as the hash in hex.
List<TraceLeg> traceLegs(TraceData trace, List<Contact> contacts) {
  String name(int hop) {
    final hex = toHex(
      trace.hashes.sublist(hop * trace.hashBytes, (hop + 1) * trace.hashBytes),
    );
    for (final c in contacts) {
      if (c.publicKey.startsWith(hex)) return c.name;
    }
    return hex.toUpperCase();
  }

  final hops = trace.snrs.length;
  return [
    for (var i = 0; i < hops; i++)
      (from: i == 0 ? 'You' : name(i - 1), to: name(i), snr: trace.snrs[i]),
    if (hops > 0) (from: name(hops - 1), to: 'You', snr: trace.finalSnr),
  ];
}
