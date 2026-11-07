import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

void main() {
  test('battery, a negative temperature and humidity', () {
    final readings = decodeLpp([
      1, 116, 0x01, 0x9A, // 4.10 V
      2, 103, 0xFF, 0x9C, // -10.0 °C
      2, 104, 0x5B, // 45.5 %
    ]);
    expect(readings, [
      const LppReading(1, LppKind.voltage, [4.1]),
      const LppReading(2, LppKind.temperature, [-10]),
      const LppReading(2, LppKind.humidity, [45.5]),
    ]);
  });

  test('a position: latitude, longitude, altitude', () {
    final r = decodeLpp([
      1, 136,
      0x06, 0x76, 0x5F, // 42.3519
      0xF2, 0x96, 0x0A, // -87.9094
      0x00, 0x03, 0xE8, // 10.00 m
    ]).single;
    expect(r.kind, LppKind.gps);
    expect(r.values[0], closeTo(42.3519, 1e-9));
    expect(r.values[1], closeTo(-87.9094, 1e-9));
    expect(r.values[2], 10);
  });

  test('pressure, current, power and three-axis values', () {
    final readings = decodeLpp([
      3, 115, 0x27, 0x97, // 1013.5 hPa
      3, 117, 0x00, 0x7B, // 0.123 A
      3, 128, 0x00, 0x05, // 5 W
      4, 113, 0x00, 0x01, 0xFF, 0xFF, 0x03, 0xE8, // 0.001, -0.001, 1 g
    ]);
    expect(readings.map((r) => r.values), [
      [1013.5],
      [0.123],
      [5],
      [0.001, -0.001, 1],
    ]);
  });

  test('stops at an unknown type and keeps what came before', () {
    final readings = decodeLpp([1, 116, 0x01, 0x9A, 1, 250, 9, 9]);
    expect(readings, [
      const LppReading(1, LppKind.voltage, [4.1]),
    ]);
  });

  test('a reading cut short is dropped', () {
    expect(decodeLpp([1, 116, 0x01, 0x9A, 2, 103, 0xFF]), [
      const LppReading(1, LppKind.voltage, [4.1]),
    ]);
  });

  test('zero padding at the end is ignored', () {
    expect(decodeLpp([1, 116, 0x01, 0x9A, 0, 0, 0, 0]), hasLength(1));
    expect(decodeLpp(const []), isEmpty);
  });

  group('commands and frames', () {
    test('asking the radio itself is four bytes', () {
      expect(const SendTelemetryRequest().encode(), [39, 0, 0, 0]);
    });

    test('asking a node adds its full key', () {
      final key = PublicKey(List.generate(32, (i) => i));
      expect(SendTelemetryRequest(key).encode(), [
        39,
        0,
        0,
        0,
        ...List.generate(32, (i) => i),
      ]);
    });

    test('a telemetry push carries the key prefix and LPP data', () {
      final frame = decodeFrame(
        Uint8List.fromList([0x8B, 0, 1, 2, 3, 4, 5, 6, 1, 116, 0x01, 0x9A]),
      );
      expect(frame, isA<TelemetryResponse>());
      final t = frame as TelemetryResponse;
      expect(t.nodePrefix, [1, 2, 3, 4, 5, 6]);
      expect(decodeLpp(t.data).single.value, 4.1);
    });
  });
}
