import 'dart:convert';
import 'dart:typed_data';

import 'bytes.dart';

/// What a node says about itself in an advert, read from the packet as
/// the MeshCore payload format lays it out: public key (32 bytes),
/// timestamp (4), signature (64), then app data: a flags byte whose low
/// nibble is the node type, then latitude and longitude (signed 32-bit,
/// millionths of a degree) when bit 0x10 is set, two optional 16-bit
/// feature fields (0x20, 0x40), and the name in the rest when 0x80 is set.
typedef AdvertData = ({
  String publicKey,
  int timestamp,
  int type,
  double? latitude,
  double? longitude,
  String? name,
});

/// Reads an advert [payload] (the bytes after the packet's path). Null
/// when it's too short to hold the fixed part.
AdvertData? parseAdvertPayload(Uint8List payload) {
  const fixed = 32 + 4 + 64;
  if (payload.length < fixed + 1) return null;
  final data = ByteData.sublistView(payload);
  final flags = payload[fixed];
  var i = fixed + 1;
  double? lat;
  double? lon;
  if (flags & 0x10 != 0) {
    if (i + 8 > payload.length) return null;
    lat = data.getInt32(i, Endian.little) / 1e6;
    lon = data.getInt32(i + 4, Endian.little) / 1e6;
    i += 8;
  }
  if (flags & 0x20 != 0) i += 2;
  if (flags & 0x40 != 0) i += 2;
  String? name;
  if (flags & 0x80 != 0 && i < payload.length) {
    var end = payload.indexOf(0, i);
    if (end < 0) end = payload.length;
    name = utf8.decode(payload.sublist(i, end), allowMalformed: true).trim();
    if (name.isEmpty) name = null;
  }
  return (
    publicKey: toHex(payload.sublist(0, 32)),
    timestamp: data.getUint32(32, Endian.little),
    type: flags & 0x0F,
    latitude: lat,
    longitude: lon,
    name: name,
  );
}
