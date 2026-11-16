import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';
import 'connection.dart';
import 'refresh_rate.dart';

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
String seriesLabel(
  TelemetrySeriesKey key, {
  bool axis = true,
  AppLocalizations? l10n,
}) {
  final suffix = axis ? ' ${_axes[key.index]}' : '';
  final base = switch (key.kind) {
    LppKind.voltage when key.channel == 1 =>
      (l10n?.sensorBatteryOwn ?? 'Battery'),
    LppKind.temperature when key.channel == 1 =>
      (l10n?.sensorChipTemperatureOwn ?? 'Chip temperature'),
    LppKind.digitalInput => (l10n?.sensorDigitalInput ?? 'Digital input'),
    LppKind.digitalOutput => (l10n?.sensorDigitalOutput ?? 'Digital output'),
    LppKind.analogInput => (l10n?.sensorAnalogInput ?? 'Analog input'),
    LppKind.analogOutput => (l10n?.sensorAnalogOutput ?? 'Analog output'),
    LppKind.genericSensor => (l10n?.sensorSensor ?? 'Sensor'),
    LppKind.luminosity => (l10n?.sensorLight ?? 'Light'),
    LppKind.presence => (l10n?.sensorPresence ?? 'Presence'),
    LppKind.temperature => (l10n?.sensorTemperature ?? 'Temperature'),
    LppKind.humidity => (l10n?.sensorHumidity ?? 'Humidity'),
    LppKind.accelerometer =>
      (l10n?.sensorAcceleration ?? 'Acceleration') + suffix,
    LppKind.barometer => (l10n?.sensorPressure ?? 'Pressure'),
    LppKind.voltage => (l10n?.sensorVoltage ?? 'Voltage'),
    LppKind.current => (l10n?.sensorCurrent ?? 'Current'),
    LppKind.frequency => (l10n?.sensorFrequency ?? 'Frequency'),
    LppKind.percentage => (l10n?.sensorLevel ?? 'Level'),
    LppKind.altitude => (l10n?.sensorAltitude ?? 'Altitude'),
    LppKind.concentration => (l10n?.sensorConcentration ?? 'Concentration'),
    LppKind.power => (l10n?.sensorPower ?? 'Power'),
    LppKind.distance => (l10n?.sensorDistance ?? 'Distance'),
    LppKind.energy => (l10n?.sensorEnergy ?? 'Energy'),
    LppKind.direction => (l10n?.sensorDirection ?? 'Direction'),
    LppKind.unixTime => (l10n?.sensorClock ?? 'Clock'),
    LppKind.gyrometer => (l10n?.sensorRotation ?? 'Rotation') + suffix,
    LppKind.colour => (l10n?.sensorColour ?? 'Colour'),
    LppKind.gps => (l10n?.sensorPosition ?? 'Position'),
    LppKind.switchState => (l10n?.sensorSwitch ?? 'Switch'),
  };
  if (key.channel <= 1) return base;
  return l10n?.sensorOnChannel(base, key.channel) ??
      '$base (sensor ${key.channel})';
}

/// A name for a whole reading, axes and all.
String readingLabel(LppReading r, [AppLocalizations? l10n]) => seriesLabel(
  (channel: r.channel, kind: r.kind, index: 0),
  axis: false,
  l10n: l10n,
);

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
  (ref) => ref.watch(refreshRateProvider).sensors,
);

/// Saves the connected radio's own readings when it connects (unless a
/// recent one is stored) and then every [selfTelemetryIntervalProvider],
/// so its battery history builds up on its own.
final selfTelemetrySamplerProvider = Provider<void>((ref) {
  final interval = ref.watch(selfTelemetryIntervalProvider);
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

/// How long ago a reading at [at] was taken.
String readingAge(DateTime at, DateTime now, [AppLocalizations? l10n]) {
  final ago = now.difference(at);
  if (ago.inMinutes < 1) return l10n?.agoJustNow ?? 'just now';
  if (ago.inHours < 1) {
    return l10n?.agoMinutes(ago.inMinutes) ?? '${ago.inMinutes} min ago';
  }
  if (ago.inDays < 1) {
    return l10n?.agoHours(ago.inHours) ?? '${ago.inHours} h ago';
  }
  return l10n?.agoDays(ago.inDays) ?? '${ago.inDays} d ago';
}

/// The connected radio's readings as one line, like
/// "Battery 3.91 V · Temperature 18.5°C", or null when there's nothing to
/// show. The chip's own temperature is left out: it says little about the
/// weather, and is still on the history screen.
String? ownStatusText(TelemetrySample sample, [AppLocalizations? l10n]) {
  final parts = [
    for (final r in decodeLpp(sample.data))
      if (isChartable(r.kind) &&
          !(r.kind == LppKind.temperature && r.channel == 1))
        '${readingLabel(r, l10n)} ${readingText(r)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

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
