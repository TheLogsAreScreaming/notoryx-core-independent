/// Network scan: a radio only hears networks on its exact settings, so this
/// switches it to each preset in its band in turn, pings for repeaters, and
/// always switches back.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presets/area_preset.dart';
import '../presets/area_presets_provider.dart';
import '../presets/community_presets.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'wardrive.dart';

/// The settings to put back if a scan was cut short, as JSON.
const scanRestoreSetting = 'scan_restore';

/// Presets further than this from the radio's frequency are another band
/// its hardware probably can't tune to.
const scanBandMhz = 30.0;

/// Time for the radio to settle on new settings before pinging.
const scanSettle = Duration(milliseconds: 1500);

bool sameSettings(RadioSettings a, RadioSettings b) =>
    (a.frequencyMhz - b.frequencyMhz).abs() < 0.001 &&
    a.bandwidthKhz == b.bandwidthKhz &&
    a.spreadingFactor == b.spreadingFactor &&
    a.codingRate == b.codingRate;

RadioSettings settingsOf(AreaPreset p) => (
  frequencyMhz: p.frequencyMhz,
  bandwidthKhz: p.bandwidthKhz,
  spreadingFactor: p.spreadingFactor,
  codingRate: p.codingRate,
);

/// The presets worth trying: in the radio's band, each distinct setting
/// once, the radio's own settings first so the scan has a baseline.
List<AreaPreset> scanCandidates(
  List<AreaPreset> presets,
  RadioSettings current,
) {
  final out = <AreaPreset>[
    AreaPreset(
      id: 'current',
      name: 'Your current settings',
      latitude: 0,
      longitude: 0,
      radiusKm: 0,
      frequencyMhz: current.frequencyMhz,
      bandwidthKhz: current.bandwidthKhz,
      spreadingFactor: current.spreadingFactor,
      codingRate: current.codingRate,
      updated: '',
    ),
  ];
  for (final p in presets) {
    if ((p.frequencyMhz - current.frequencyMhz).abs() > scanBandMhz) continue;
    if (out.any((o) => sameSettings(settingsOf(o), settingsOf(p)))) continue;
    out.add(p);
  }
  return out;
}

String encodeSettings(RadioSettings s) => jsonEncode({
  'f': s.frequencyMhz,
  'bw': s.bandwidthKhz,
  'sf': s.spreadingFactor,
  'cr': s.codingRate,
});

RadioSettings? decodeSettings(String? raw) {
  if (raw == null) return null;
  try {
    final j = jsonDecode(raw) as Map<String, Object?>;
    return (
      frequencyMhz: (j['f']! as num).toDouble(),
      bandwidthKhz: (j['bw']! as num).toDouble(),
      spreadingFactor: j['sf']! as int,
      codingRate: j['cr']! as int,
    );
  } on Object {
    return null;
  }
}

/// What one preset found.
typedef ScanResult = ({AreaPreset preset, List<WardriveHit> hits});

/// Runs a scan over [candidates]. [apply] switches the radio (null means
/// back to the original); it is always called with null at the end, even
/// when a step fails or [cancelled] turns true.
Future<List<ScanResult>> runScan({
  required List<AreaPreset> candidates,
  required Future<void> Function(AreaPreset? preset) apply,
  required Future<List<WardriveHit>> Function() ping,
  bool Function()? cancelled,
  void Function(int done, List<ScanResult> results)? progress,
  Duration settle = scanSettle,
}) async {
  final results = <ScanResult>[];
  try {
    for (final preset in candidates) {
      if (cancelled?.call() ?? false) break;
      await apply(preset);
      await Future<void>.delayed(settle);
      results.add((preset: preset, hits: await ping()));
      progress?.call(results.length, results);
    }
  } finally {
    await apply(null);
  }
  return results;
}

final class ScanState {
  const ScanState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.results = const [],
    this.error,
  });

  final bool running;
  final int done;
  final int total;
  final List<ScanResult> results;
  final String? error;
}

class NetworkScan extends Notifier<ScanState> {
  bool _cancel = false;

  @override
  ScanState build() => const ScanState();

  void cancel() => _cancel = true;

  Future<void> start() async {
    final connection = ref.read(connectionProvider);
    final current = ref.read(radioSettingsProvider);
    if (state.running || connection is! Connected || current == null) return;
    final presets = [
      ...await ref.read(communityPresetsProvider.future),
      ...await ref.read(areaPresetsProvider.future),
    ];
    final candidates = scanCandidates(presets, current);
    final store = ref.read(storeProvider);
    final controller = ref.read(connectionProvider.notifier);
    // Saved first, so a scan cut short by the app closing is undone on the
    // next connect.
    await store.saveSetting(scanRestoreSetting, encodeSettings(current));
    _cancel = false;
    state = ScanState(running: true, total: candidates.length);
    try {
      final results = await runScan(
        candidates: candidates,
        apply: (p) async {
          final s = p == null ? current : settingsOf(p);
          await controller.setRadioParams(
            SetRadioParams(
              frequencyMhz: s.frequencyMhz,
              bandwidthKhz: s.bandwidthKhz,
              spreadingFactor: s.spreadingFactor,
              codingRate: s.codingRate,
            ),
          );
          if (p == null) await store.removeSetting(scanRestoreSetting);
        },
        ping: () => pingRepeaters(connection.sync.session),
        cancelled: () => _cancel,
        progress: (done, results) => state = ScanState(
          running: true,
          done: done,
          total: candidates.length,
          results: [...results],
        ),
      );
      state = ScanState(
        done: results.length,
        total: candidates.length,
        results: results,
      );
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('network scan: $e');
      state = ScanState(
        done: state.done,
        total: state.total,
        results: state.results,
        error: '$e',
      );
    }
  }
}

final networkScanProvider = NotifierProvider<NetworkScan, ScanState>(
  NetworkScan.new,
);

/// Puts the radio back after a scan the app didn't finish.
final scanRestoreProvider = Provider<void>((ref) {
  if (ref.watch(connectionProvider) is! Connected) return;
  if (ref.read(networkScanProvider).running) return;
  unawaited(() async {
    final store = ref.read(storeProvider);
    final saved = decodeSettings(await store.setting(scanRestoreSetting));
    if (saved == null) return;
    try {
      await ref
          .read(connectionProvider.notifier)
          .setRadioParams(
            SetRadioParams(
              frequencyMhz: saved.frequencyMhz,
              bandwidthKhz: saved.bandwidthKhz,
              spreadingFactor: saved.spreadingFactor,
              codingRate: saved.codingRate,
            ),
          );
      await store.removeSetting(scanRestoreSetting);
      ref.read(connectionLogProvider).add('network scan: settings restored');
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('network scan restore: $e');
    }
  }());
});
