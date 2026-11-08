import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'connection.dart';
import 'telemetry.dart' show TelemetryPoint;

/// A radio's stored receiver figures, oldest first.
final radioStatsHistoryProvider =
    StreamProvider.family<List<RadioStatsSample>, String>(
      (ref, radioKey) => ref.watch(storeProvider).watchRadioStats(radioKey),
    );

/// How often the connected radio's noise floor is saved. It is read over
/// the cable or Bluetooth, so it costs no airtime.
final radioStatsIntervalProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 10),
);

/// Saves the connected radio's receiver figures when it connects (unless a
/// recent sample is stored) and then every [radioStatsIntervalProvider].
/// Stops for the connection when the firmware has no stats.
final radioStatsSamplerProvider = Provider<void>((ref) {
  final interval = ref.read(radioStatsIntervalProvider);
  Timer? timer;

  Future<void> sample(MeshSync sync) async {
    try {
      if (await sync.sampleRadioStats() == null) {
        timer?.cancel();
        timer = null;
      }
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('radio stats: $e');
    }
  }

  Future<void> follow(RadioConnectionState state) async {
    timer?.cancel();
    timer = null;
    if (state is! Connected) return;
    final key = state.radio.self.publicKey.hex;
    final last = await ref.read(storeProvider).lastRadioStatsAt(key);
    if (ref.read(connectionProvider) != state) return;
    timer = Timer.periodic(interval, (_) => unawaited(sample(state.sync)));
    if (last == null || DateTime.now().difference(last) >= interval) {
      unawaited(sample(state.sync));
    }
  }

  ref.onDispose(() => timer?.cancel());
  unawaited(follow(ref.read(connectionProvider)));
  ref.listen(connectionProvider, (_, next) => unawaited(follow(next)));
});

/// The figures charted from receiver samples.
enum RadioStatsSeries {
  noiseFloor('Noise floor', 'dBm'),
  lastRssi('Last packet signal', 'dBm'),
  lastSnr('Last packet SNR', 'dB');

  const RadioStatsSeries(this.label, this.unit);

  final String label;
  final String unit;

  double valueOf(RadioStatsSample s) => switch (this) {
    noiseFloor => s.noiseFloor.toDouble(),
    lastRssi => s.lastRssi.toDouble(),
    lastSnr => s.lastSnr,
  };

  String format(double v) =>
      '${v.toStringAsFixed(this == lastSnr ? 1 : 0)} $unit';

  List<TelemetryPoint> points(List<RadioStatsSample> samples) => [
    for (final s in samples)
      (at: DateTime.fromMillisecondsSinceEpoch(s.at), value: valueOf(s)),
  ];
}

/// A plain-words reading of a noise floor, in dBm.
String noiseVerdict(int dbm) => switch (dbm) {
  <= -115 => 'Quiet. Weak signals get through.',
  <= -105 => 'Normal.',
  <= -95 => 'Noisy. Weak signals may be missed.',
  _ => 'Very noisy. Something nearby is drowning out the mesh.',
};

/// "2 h 5 min" for an airtime total.
String formatAirtime(int seconds) {
  final d = Duration(seconds: seconds);
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
  return '$seconds s';
}
