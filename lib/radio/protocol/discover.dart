/// Repeater discovery: a zero-hop control packet that repeaters in range
/// answer with their key and how well they heard the asker.
library;

import 'dart:typed_data';

import 'bytes.dart';

const _discoverRequest = 0x80;
const _discoverResponse = 0x90;
const _repeaterType = 2;

/// The control payload asking repeaters within one hop to answer, matched by
/// [tag].
Uint8List discoverRequest(int tag) => Uint8List.fromList([
  _discoverRequest,
  1 << _repeaterType, // only repeaters
  tag & 0xFF,
  (tag >> 8) & 0xFF,
  (tag >> 16) & 0xFF,
  (tag >> 24) & 0xFF,
]);

/// One repeater's answer.
typedef DiscoverAnswer = ({
  int tag,
  String publicKey,

  /// How well it heard us, in dB.
  double heardUs,
});

/// [payload] as a repeater's answer, or null.
DiscoverAnswer? parseDiscoverAnswer(Uint8List payload) {
  if (payload.length < 6 + 32) return null;
  if (payload[0] & 0xF0 != _discoverResponse) return null;
  if (payload[0] & 0x0F != _repeaterType) return null;
  final snr = payload[1] >= 128 ? payload[1] - 256 : payload[1];
  final tag = ByteData.sublistView(payload, 2, 6).getUint32(0, Endian.little);
  return (tag: tag, publicKey: toHex(payload.sublist(6, 38)), heardUs: snr / 4);
}
