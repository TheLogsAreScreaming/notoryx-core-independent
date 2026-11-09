/// Finding the best antenna position by ear: pings one repeater over and
/// over and clicks faster as it gets louder.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Quiet end of the click scale, in dB of signal-to-noise.
const huntQuietSnr = -20.0;

/// Loud end of the click scale.
const huntLoudSnr = 12.0;

/// How long between clicks at [snr]: slow when faint, fast when loud.
Duration clickInterval(double snr) {
  final loudness = ((snr - huntQuietSnr) / (huntLoudSnr - huntQuietSnr)).clamp(
    0.0,
    1.0,
  );
  return Duration(milliseconds: (1500 - loudness * 1380).round());
}

/// Runs a hunt. Each ping is a real transmission, so pings are spaced out
/// and the hunt stops by itself after [maxRun].
class AntennaHunt extends ChangeNotifier {
  AntennaHunt({
    required this.ping,
    required this.click,
    this.pingEvery = const Duration(seconds: 5),
    this.maxRun = const Duration(minutes: 5),
  });

  /// Sends one ping. Returns how loud the repeater was, or null for no
  /// answer.
  final Future<double?> Function() ping;
  final VoidCallback click;
  final Duration pingEvery;
  final Duration maxRun;

  bool running = false;

  /// Whether the last hunt ended on its time limit.
  bool timedOut = false;
  double? latest;
  double? best;

  /// Whether a ping has come back empty since the last answer.
  bool lost = false;

  Timer? _next;
  Timer? _clicks;
  Timer? _limit;
  int _run = 0;

  void start() {
    if (running) return;
    running = true;
    timedOut = false;
    latest = null;
    best = null;
    lost = false;
    final run = ++_run;
    _limit = Timer(maxRun, () {
      timedOut = true;
      stop();
    });
    notifyListeners();
    unawaited(_ping(run));
  }

  void stop() {
    if (!running) return;
    running = false;
    _cancel();
    notifyListeners();
  }

  void _cancel() {
    _next?.cancel();
    _clicks?.cancel();
    _limit?.cancel();
  }

  Future<void> _ping(int run) async {
    double? snr;
    try {
      snr = await ping();
    } on Object {
      snr = null;
    }
    if (run != _run || !running) return;
    latest = snr;
    lost = snr == null;
    if (snr != null && (best == null || snr > best!)) best = snr;
    _clicks?.cancel();
    if (snr != null) _scheduleClick(run, snr);
    notifyListeners();
    _next = Timer(pingEvery, () => unawaited(_ping(run)));
  }

  void _scheduleClick(int run, double snr) {
    _clicks = Timer(clickInterval(snr), () {
      if (run != _run || !running) return;
      click();
      _scheduleClick(run, snr);
    });
  }

  @override
  void dispose() {
    _run++;
    running = false;
    _cancel();
    super.dispose();
  }
}
