import 'dart:typed_data';

/// What a telemetry reading measures. Values are the Cayenne LPP type
/// bytes MeshCore radios send in telemetry replies.
enum LppKind {
  digitalInput(0, 1, 1, ''),
  digitalOutput(1, 1, 1, ''),
  analogInput(2, 2, 100, '', signed: true),
  analogOutput(3, 2, 100, '', signed: true),
  genericSensor(100, 4, 1, ''),
  luminosity(101, 2, 1, 'lx'),
  presence(102, 1, 1, ''),
  temperature(103, 2, 10, '°C', signed: true),
  humidity(104, 1, 2, '%'),
  accelerometer(113, 2, 1000, 'g', signed: true, count: 3),
  barometer(115, 2, 10, 'hPa'),
  voltage(116, 2, 100, 'V'),
  current(117, 2, 1000, 'A'),
  frequency(118, 4, 1, 'Hz'),
  percentage(120, 1, 1, '%'),
  altitude(121, 2, 1, 'm', signed: true),
  concentration(125, 2, 1, 'ppm'),
  power(128, 2, 1, 'W'),
  distance(130, 4, 1000, 'm'),
  energy(131, 4, 1000, 'kWh'),
  direction(132, 2, 1, '°'),
  unixTime(133, 4, 1, ''),
  gyrometer(134, 2, 100, '°/s', signed: true, count: 3),
  colour(135, 1, 1, '', count: 3),
  gps(136, 3, 1, '', signed: true, count: 3),
  switchState(142, 1, 1, '');

  const LppKind(
    this.value,
    this.width,
    this.divisor,
    this.unit, {
    this.signed = false,
    this.count = 1,
  });

  /// The type byte.
  final int value;

  /// Bytes per value.
  final int width;

  /// What the raw integer is divided by.
  final int divisor;
  final String unit;
  final bool signed;

  /// Values per reading: 3 for axes, colour and position.
  final int count;

  int get size => width * count;

  static LppKind? from(int value) {
    for (final k in values) {
      if (k.value == value) return k;
    }
    return null;
  }
}

/// One reading from a telemetry reply. [channel] tells sensors apart: 1 is
/// the device itself, higher numbers are attached sensors.
final class LppReading {
  const LppReading(this.channel, this.kind, this.values);

  final int channel;
  final LppKind kind;

  /// Scaled values. For [LppKind.gps]: latitude, longitude, altitude (m).
  final List<double> values;

  double get value => values.first;

  @override
  bool operator ==(Object other) =>
      other is LppReading &&
      other.channel == channel &&
      other.kind == kind &&
      _sameValues(other.values, values);

  @override
  int get hashCode => Object.hash(channel, kind, Object.hashAll(values));

  @override
  String toString() => 'LppReading($channel, ${kind.name}, $values)';
}

bool _sameValues(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Reads the Cayenne LPP block of a telemetry reply: repeated channel byte,
/// type byte, then big-endian values. Stops at the first type it doesn't
/// know or a reading cut short, keeping what came before. Trailing zero
/// padding is ignored.
List<LppReading> decodeLpp(List<int> data) {
  final bytes = Uint8List.fromList(data);
  final view = ByteData.sublistView(bytes);
  final readings = <LppReading>[];
  var i = 0;
  while (i + 2 <= bytes.length) {
    final channel = bytes[i];
    final kind = LppKind.from(bytes[i + 1]);
    if (kind == null) break;
    if (channel == 0 && kind == LppKind.digitalInput && _allZero(bytes, i)) {
      break;
    }
    i += 2;
    if (i + kind.size > bytes.length) break;
    final values = <double>[];
    for (var v = 0; v < kind.count; v++) {
      final raw = _int(view, i, kind.width, signed: kind.signed);
      i += kind.width;
      values.add(raw / _divisor(kind, v));
    }
    readings.add(LppReading(channel, kind, values));
  }
  return readings;
}

bool _allZero(Uint8List bytes, int from) {
  for (var i = from; i < bytes.length; i++) {
    if (bytes[i] != 0) return false;
  }
  return true;
}

int _divisor(LppKind kind, int index) {
  if (kind != LppKind.gps) return kind.divisor;
  return index < 2 ? 10000 : 100;
}

int _int(ByteData view, int offset, int width, {required bool signed}) {
  var value = 0;
  for (var b = 0; b < width; b++) {
    value = (value << 8) | view.getUint8(offset + b);
  }
  if (signed && value & (1 << (width * 8 - 1)) != 0) {
    value -= 1 << (width * 8);
  }
  return value;
}
