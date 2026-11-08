import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import 'connection.dart';

/// A node's stored telemetry, oldest first.
final telemetryHistoryProvider =
    StreamProvider.family<
      List<TelemetrySample>,
      ({String radioKey, String nodeKey})
    >(
      (ref, id) =>
          ref.watch(storeProvider).watchTelemetry(id.radioKey, id.nodeKey),
    );

/// One line on a chart: a single value of one sensor over time.
typedef TelemetrySeriesKey = ({int channel, LppKind kind, int index});

/// A reading's value at a moment.
typedef TelemetryPoint = ({DateTime at, double value});

/// Kinds that make sense as a line over time.
bool isChartable(LppKind kind) => switch (kind) {
  LppKind.gps || LppKind.colour || LppKind.unixTime => false,
  _ => true,
};

/// Splits stored replies into one series per sensor value, in the order
/// they first appear. Unreadable replies are skipped.
Map<TelemetrySeriesKey, List<TelemetryPoint>> telemetrySeries(
  List<TelemetrySample> samples,
) {
  final series = <TelemetrySeriesKey, List<TelemetryPoint>>{};
  for (final s in samples) {
    final at = DateTime.fromMillisecondsSinceEpoch(s.at);
    for (final r in decodeLpp(s.data)) {
      if (!isChartable(r.kind)) continue;
      for (var i = 0; i < r.values.length; i++) {
        final key = (channel: r.channel, kind: r.kind, index: i);
        (series[key] ??= []).add((at: at, value: r.values[i]));
      }
    }
  }
  return series;
}

const _axes = ['x', 'y', 'z'];

/// A name for one sensor value, e.g. "Battery" or "Temperature (sensor 2)".
String seriesLabel(TelemetrySeriesKey key, {bool axis = true}) {
  final suffix = axis ? ' ${_axes[key.index]}' : '';
  final base = switch (key.kind) {
    LppKind.voltage when key.channel == 1 => 'Battery',
    LppKind.temperature when key.channel == 1 => 'Chip temperature',
    LppKind.digitalInput => 'Digital input',
    LppKind.digitalOutput => 'Digital output',
    LppKind.analogInput => 'Analog input',
    LppKind.analogOutput => 'Analog output',
    LppKind.genericSensor => 'Sensor',
    LppKind.luminosity => 'Light',
    LppKind.presence => 'Presence',
    LppKind.temperature => 'Temperature',
    LppKind.humidity => 'Humidity',
    LppKind.accelerometer => 'Acceleration$suffix',
    LppKind.barometer => 'Pressure',
    LppKind.voltage => 'Voltage',
    LppKind.current => 'Current',
    LppKind.frequency => 'Frequency',
    LppKind.percentage => 'Level',
    LppKind.altitude => 'Altitude',
    LppKind.concentration => 'Concentration',
    LppKind.power => 'Power',
    LppKind.distance => 'Distance',
    LppKind.energy => 'Energy',
    LppKind.direction => 'Direction',
    LppKind.unixTime => 'Clock',
    LppKind.gyrometer => 'Rotation$suffix',
    LppKind.colour => 'Colour',
    LppKind.gps => 'Position',
    LppKind.switchState => 'Switch',
  };
  return key.channel > 1 ? '$base (sensor ${key.channel})' : base;
}

/// A name for a whole reading, axes and all.
String readingLabel(LppReading r) =>
    seriesLabel((channel: r.channel, kind: r.kind, index: 0), axis: false);

/// [value] with the right precision and unit for [kind].
String formatValue(LppKind kind, double value) {
  final digits = switch (kind) {
    LppKind.voltage || LppKind.analogInput || LppKind.analogOutput => 2,
    LppKind.current || LppKind.accelerometer || LppKind.energy => 3,
    LppKind.temperature || LppKind.barometer || LppKind.humidity => 1,
    LppKind.gyrometer || LppKind.distance => 2,
    _ => 0,
  };
  final unit = kind.unit;
  final text = value.toStringAsFixed(digits);
  if (unit.isEmpty) return text;
  return unit == '%' || unit.startsWith('°') ? '$text$unit' : '$text $unit';
}

/// One reading as a line of text, for the "latest" list.
String readingText(LppReading r) => switch (r.kind) {
  LppKind.gps =>
    '${r.values[0].toStringAsFixed(5)}, ${r.values[1].toStringAsFixed(5)}'
        ' · ${r.values[2].toStringAsFixed(0)} m',
  LppKind.colour => 'RGB ${r.values.map((v) => v.toInt()).join(', ')}',
  LppKind.unixTime => DateTime.fromMillisecondsSinceEpoch(
    r.value.toInt() * 1000,
  ).toLocal().toString().substring(0, 19),
  LppKind.accelerometer ||
  LppKind.gyrometer => r.values.map((v) => formatValue(r.kind, v)).join(' · '),
  _ => formatValue(r.kind, r.value),
};

/// How often the connected radio's own readings are saved while connected.
/// They come over the cable or Bluetooth, so they cost no airtime.
final selfTelemetryIntervalProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 30),
);

/// Saves the connected radio's own readings when it connects (unless a
/// recent one is stored) and then every [selfTelemetryIntervalProvider],
/// so its battery history builds up on its own.
final selfTelemetrySamplerProvider = Provider<void>((ref) {
  final interval = ref.read(selfTelemetryIntervalProvider);
  Timer? timer;

  Future<void> sample(MeshSync sync) async {
    try {
      await sync.requestTelemetry();
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('telemetry: $e');
    }
  }

  Future<void> follow(RadioConnectionState state) async {
    timer?.cancel();
    timer = null;
    if (state is! Connected) return;
    final store = ref.read(storeProvider);
    final key = state.radio.self.publicKey.hex;
    final last = await store.lastTelemetryAt(key, key);
    if (ref.read(connectionProvider) != state) return;
    if (last == null || DateTime.now().difference(last) >= interval) {
      unawaited(sample(state.sync));
    }
    timer = Timer.periodic(interval, (_) => unawaited(sample(state.sync)));
  }

  ref.onDispose(() => timer?.cancel());
  unawaited(follow(ref.read(connectionProvider)));
  ref.listen(connectionProvider, (_, next) => unawaited(follow(next)));
});

/// Each node's newest telemetry reply, by node key.
final latestTelemetryProvider =
    StreamProvider.family<Map<String, TelemetrySample>, String>(
      (ref, radioKey) =>
          ref.watch(storeProvider).watchLatestTelemetry(radioKey),
    );

/// How long a reading stays on the map. Older ones could mislead.
const telemetryBadgeMaxAge = Duration(hours: 24);

/// Short text for a node's map marker, like "3.91 V · 18.5°C", or null
/// when [sample] is too old or holds nothing worth showing.
String? telemetryBadge(TelemetrySample sample, {DateTime? now}) {
  final at = DateTime.fromMillisecondsSinceEpoch(sample.at);
  if ((now ?? DateTime.now()).difference(at) > telemetryBadgeMaxAge) {
    return null;
  }
  String? battery;
  String? temperature;
  for (final r in decodeLpp(sample.data)) {
    if (r.channel == 1 && r.kind == LppKind.voltage) {
      battery = formatValue(r.kind, r.value);
    } else if (r.kind == LppKind.percentage) {
      battery ??= formatValue(r.kind, r.value);
    } else if (r.kind == LppKind.temperature && r.channel > 1) {
      // Channel 1 is the chip, which says little about the weather.
      temperature ??= formatValue(r.kind, r.value);
    }
  }
  final parts = [?battery, ?temperature];
  return parts.isEmpty ? null : parts.join(' · ');
}
