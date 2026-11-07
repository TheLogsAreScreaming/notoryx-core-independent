import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../radio/radio.dart';
import 'connection.dart';

/// One packet the radio heard, with when and how well.
typedef HeardPacket = ({
  DateTime at,
  double snr,
  int rssi,
  PacketHeader? header,
  int length,
});

/// The packets heard while connected this run, newest last. Keeps the
/// latest [PacketLog.capacity]; nothing is saved.
final packetLogProvider = NotifierProvider<PacketLog, List<HeardPacket>>(
  PacketLog.new,
);

class PacketLog extends Notifier<List<HeardPacket>> {
  static const capacity = 500;

  StreamSubscription<RxLog>? _sub;

  /// Whether new packets are being added. Paused keeps the list still to
  /// read it.
  bool paused = false;

  @override
  List<HeardPacket> build() {
    ref.listen(
      connectionProvider,
      (_, next) => _follow(next),
      fireImmediately: true,
    );
    ref.onDispose(() => _sub?.cancel());
    return const [];
  }

  void _follow(RadioConnectionState state) {
    unawaited(_sub?.cancel());
    _sub = null;
    if (state is! Connected) return;
    _sub = state.sync.heard.listen(add);
  }

  /// Records [log], heard now.
  void add(RxLog log, {DateTime? at}) {
    if (paused) return;
    final entry = (
      at: at ?? DateTime.now(),
      snr: log.snr,
      rssi: log.rssi,
      header: PacketHeader.parse(log.packet),
      length: log.packet.length,
    );
    final next = [...state, entry];
    state = next.length > capacity
        ? next.sublist(next.length - capacity)
        : next;
  }

  void clear() => state = const [];

  void setPaused(bool value) {
    paused = value;
    ref.notifyListeners();
  }
}
