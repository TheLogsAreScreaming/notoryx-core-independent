import 'dart:typed_data';

import 'bytes.dart';

/// A repeater's or room server's status, from its reply to a status
/// request. The layout is the firmware's `RepeaterStats` / `ServerStats`
/// structs: a shared 48-byte start, then 8 bytes more on repeaters or 4 on
/// room servers.
final class ServerStatus {
  const ServerStatus({
    required this.batteryMillivolts,
    required this.txQueue,
    required this.noiseFloor,
    required this.lastRssi,
    required this.packetsReceived,
    required this.packetsSent,
    required this.airTimeSeconds,
    required this.upTimeSeconds,
    required this.sentFlood,
    required this.sentDirect,
    required this.receivedFlood,
    required this.receivedDirect,
    required this.errorEvents,
    required this.lastSnr,
    required this.directDuplicates,
    required this.floodDuplicates,
    this.receiveAirTimeSeconds,
    this.receiveErrors,
    this.posts,
    this.postPushes,
  });

  /// Reads a status block. Returns null when it's too short to be one.
  static ServerStatus? parse(List<int> data) {
    if (data.length < 48) return null;
    final r = FrameReader(Uint8List.fromList(data));
    final common = (
      battery: r.u16(),
      queue: r.u16(),
      noise: r.i16(),
      rssi: r.i16(),
      received: r.u32(),
      sent: r.u32(),
      air: r.u32(),
      up: r.u32(),
      sentFlood: r.u32(),
      sentDirect: r.u32(),
      receivedFlood: r.u32(),
      receivedDirect: r.u32(),
      errors: r.u16(),
      snr: r.i16() / 4,
      directDups: r.u16(),
      floodDups: r.u16(),
    );
    final repeater = r.remaining >= 8;
    final room = !repeater && r.remaining >= 4;
    return ServerStatus(
      batteryMillivolts: common.battery,
      txQueue: common.queue,
      noiseFloor: common.noise,
      lastRssi: common.rssi,
      packetsReceived: common.received,
      packetsSent: common.sent,
      airTimeSeconds: common.air,
      upTimeSeconds: common.up,
      sentFlood: common.sentFlood,
      sentDirect: common.sentDirect,
      receivedFlood: common.receivedFlood,
      receivedDirect: common.receivedDirect,
      errorEvents: common.errors,
      lastSnr: common.snr,
      directDuplicates: common.directDups,
      floodDuplicates: common.floodDups,
      receiveAirTimeSeconds: repeater ? r.u32() : null,
      receiveErrors: repeater ? r.u32() : null,
      posts: room ? r.u16() : null,
      postPushes: room ? r.u16() : null,
    );
  }

  final int batteryMillivolts;
  final int txQueue;

  /// dBm.
  final int noiseFloor;
  final int lastRssi;
  final int packetsReceived;
  final int packetsSent;

  /// Time spent transmitting since boot.
  final int airTimeSeconds;
  final int upTimeSeconds;
  final int sentFlood;
  final int sentDirect;
  final int receivedFlood;
  final int receivedDirect;
  final int errorEvents;

  /// dB.
  final double lastSnr;
  final int directDuplicates;
  final int floodDuplicates;

  // Repeaters only.
  final int? receiveAirTimeSeconds;
  final int? receiveErrors;

  // Room servers only.
  final int? posts;
  final int? postPushes;
}
