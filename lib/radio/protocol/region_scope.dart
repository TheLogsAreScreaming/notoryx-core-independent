/// Region scoping: repeaters that allow a region pass on floods marked with
/// that region's code. The code is keyed by the region name, so a code can
/// only be recognised by trying names the app already knows.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'packet_header.dart';

/// [name] without a leading # or spaces, lower case. Null when empty.
String? cleanRegionName(String? name) {
  var n = name?.trim().toLowerCase() ?? '';
  while (n.startsWith('#')) {
    n = n.substring(1).trim();
  }
  return n.isEmpty ? null : n;
}

/// The names in a comma or space separated [list], without repeats.
List<String> regionNames(String? list) => {
  for (final part in (list ?? '').split(RegExp(r'[,\s]+')))
    ?cleanRegionName(part),
}.toList();

/// The 16-byte key of public region [name].
Uint8List regionKey(String name) => Uint8List.fromList(
  sha256
      .convert('#${cleanRegionName(name) ?? ''}'.codeUnits)
      .bytes
      .sublist(0, 16),
);

/// The code a packet of [payloadType] carrying [payload] has under [key].
int regionCode(Uint8List key, int payloadType, List<int> payload) {
  final mac = Hmac(sha256, key).convert([payloadType, ...payload]).bytes;
  final code = mac[0] | (mac[1] << 8);
  // The firmware reserves 0000 and FFFF.
  if (code == 0) return 1;
  if (code == 0xFFFF) return 0xFFFE;
  return code;
}

/// A region-scoped channel post heard on air.
typedef ScopedPost = ({int channelHash, String region, Uint8List payload});

/// [raw] as a scoped channel post in one of [regions]. Null for anything
/// else, including a region not in the list.
ScopedPost? scopedPost(Uint8List raw, List<String> regions) {
  final header = PacketHeader.parse(raw);
  final channelHash = header?.channelHash;
  if (header == null ||
      channelHash == null ||
      header.route != RouteKind.transportFlood) {
    return null;
  }
  final payload = Uint8List.sublistView(raw, raw.length - header.payloadLength);
  final code = raw[1] | (raw[2] << 8);
  for (final region in regions) {
    if (regionCode(regionKey(region), header.payload.value, payload) == code) {
      return (channelHash: channelHash, region: region, payload: payload);
    }
  }
  return null;
}

/// The sender's timestamp inside channel post [payload] (key hash, 2-byte
/// MAC, then AES blocks), or null if it holds no whole block.
int? channelPostTime(Uint8List payload, Uint8List secret) {
  if (payload.length < 3 + 16 || secret.length < 16) return null;
  final aes = AESEngine()
    ..init(false, KeyParameter(Uint8List.sublistView(secret, 0, 16)));
  final block = Uint8List(16);
  aes.processBlock(payload, 3, block, 0);
  return ByteData.sublistView(block).getUint32(0, Endian.little);
}
