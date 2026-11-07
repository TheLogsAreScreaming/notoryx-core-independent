import 'dart:typed_data';

import 'bytes.dart';

/// How a mesh packet travels.
enum RouteKind {
  transportFlood('flood'),
  flood('flood'),
  direct('direct'),
  transportDirect('direct');

  const RouteKind(this.label);

  final String label;
}

/// What a mesh packet carries, from the 4-bit type in its header.
enum PayloadKind {
  request(0x0, 'Request'),
  response(0x1, 'Response'),
  text(0x2, 'Direct message'),
  ack(0x3, 'Ack'),
  advert(0x4, 'Advert'),
  groupText(0x5, 'Channel message'),
  groupData(0x6, 'Channel data'),
  anonRequest(0x7, 'Login or anonymous request'),
  path(0x8, 'Returned path'),
  trace(0x9, 'Trace'),
  multipart(0xA, 'Multipart'),
  control(0xB, 'Control'),
  rawCustom(0xF, 'Custom'),
  unknown(-1, 'Unknown');

  const PayloadKind(this.value, this.label);

  final int value;
  final String label;

  static PayloadKind fromValue(int v) =>
      values.firstWhere((k) => k.value == v, orElse: () => unknown);
}

/// The readable parts of a raw packet the radio heard over the air. The
/// rest is encrypted or not interesting at a glance.
final class PacketHeader {
  const PacketHeader({
    required this.route,
    required this.payload,
    required this.version,
    required this.hashBytes,
    required this.path,
    required this.payloadLength,
    this.advertKey,
    this.channelHash,
  });

  /// Reads the header of [raw], laid out as the firmware sends it: header
  /// byte, transport codes for transport routes, path length, path, then
  /// payload. Null if it's too short to be a packet.
  static PacketHeader? parse(Uint8List raw) {
    if (raw.length < 2) return null;
    final header = raw[0];
    final route = RouteKind.values[header & 0x03];
    var i = 1;
    if (route == RouteKind.transportFlood ||
        route == RouteKind.transportDirect) {
      i += 4;
    }
    if (i >= raw.length) return null;
    final pathLength = raw[i++];
    final hashBytes = (pathLength >> 6) + 1;
    final pathBytes = (pathLength & 0x3F) * hashBytes;
    if (i + pathBytes > raw.length) return null;
    final path = Uint8List.sublistView(raw, i, i + pathBytes);
    i += pathBytes;
    final payload = PayloadKind.fromValue((header >> 2) & 0x0F);
    final rest = raw.length - i;
    return PacketHeader(
      route: route,
      payload: payload,
      version: header >> 6,
      hashBytes: hashBytes,
      path: path,
      payloadLength: rest,
      advertKey: payload == PayloadKind.advert && rest >= 32
          ? toHex(raw.sublist(i, i + 32))
          : null,
      channelHash: payload == PayloadKind.groupText && rest >= 1
          ? raw[i]
          : null,
    );
  }

  final RouteKind route;
  final PayloadKind payload;
  final int version;

  /// Bytes in each hop's hash in [path].
  final int hashBytes;

  /// For floods: the repeaters that passed it on so far, oldest first. For
  /// direct packets: the hops still to go.
  final Uint8List path;
  final int payloadLength;

  /// Adverts: the sender's full public key, in hex.
  final String? advertKey;

  /// Channel messages: the first byte of the channel's key hash.
  final int? channelHash;

  int get hopCount => path.length ~/ hashBytes;

  /// The hop hashes in [path], in hex.
  List<String> get hops => [
    for (var h = 0; h < hopCount; h++)
      toHex(path.sublist(h * hashBytes, (h + 1) * hashBytes)),
  ];
}
