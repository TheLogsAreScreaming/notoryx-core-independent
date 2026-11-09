import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/telemetry.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

TelemetrySample _sample(int id, List<int> data) => TelemetrySample(
  id: id,
  radioKey: 'r',
  nodeKey: 'n',
  at: id * 60000,
  data: Uint8List.fromList(data),
);

void main() {
  test('the home line shows battery and sensors, not the chip', () {
    // Battery on channel 1, chip temperature on 1, a real sensor on 2.
    final text = ownStatusText(
      _sample(1, [1, 116, 0x01, 0x9A, 1, 103, 0x01, 0x90, 2, 103, 0x00, 0xC8]),
    );
    expect(text, 'Battery 4.10 V · Temperature (sensor 2) 20.0°C');
  });

  test('a reading with nothing to show gives no home line', () {
    expect(ownStatusText(_sample(1, [])), isNull);
  });

  test('reading ages read naturally', () {
    final now = DateTime(2026, 11, 8, 12);
    String ago(Duration d) => readingAge(now.subtract(d), now);
    expect(ago(const Duration(seconds: 20)), 'just now');
    expect(ago(const Duration(minutes: 5)), '5 min ago');
    expect(ago(const Duration(hours: 3)), '3 h ago');
    expect(ago(const Duration(days: 2)), '2 d ago');
  });

  test('replies split into one series per sensor value', () {
    final series = telemetrySeries([
      _sample(1, [1, 116, 0x01, 0x9A, 2, 103, 0x00, 0xC8]),
      _sample(2, [1, 116, 0x01, 0x90]),
      _sample(3, [1, 116, 0x01, 0x86, 1, 136, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
    ]);
    const battery = (channel: 1, kind: LppKind.voltage, index: 0);
    const temp = (channel: 2, kind: LppKind.temperature, index: 0);
    expect(series.keys, [battery, temp]);
    expect(series[battery]!.map((p) => p.value), [4.1, 4.0, 3.9]);
    expect(series[temp]!.single.value, 20.0);
  });

  test('three-axis readings become three lines', () {
    final series = telemetrySeries([
      _sample(1, [4, 113, 0, 1, 0, 2, 0, 3]),
    ]);
    expect(series.keys.map(seriesLabel), [
      'Acceleration x (sensor 4)',
      'Acceleration y (sensor 4)',
      'Acceleration z (sensor 4)',
    ]);
  });

  test('labels name the device itself and attached sensors', () {
    expect(
      seriesLabel((channel: 1, kind: LppKind.voltage, index: 0)),
      'Battery',
    );
    expect(
      seriesLabel((channel: 2, kind: LppKind.voltage, index: 0)),
      'Voltage (sensor 2)',
    );
    expect(
      seriesLabel((channel: 1, kind: LppKind.temperature, index: 0)),
      'Chip temperature',
    );
    expect(
      readingLabel(const LppReading(3, LppKind.gyrometer, [1, 2, 3])),
      'Rotation (sensor 3)',
    );
  });

  test('values get units and sensible precision', () {
    expect(formatValue(LppKind.voltage, 4.1), '4.10 V');
    expect(formatValue(LppKind.temperature, -3.25), '-3.3°C');
    expect(formatValue(LppKind.humidity, 45.5), '45.5%');
    expect(formatValue(LppKind.barometer, 1013.5), '1013.5 hPa');
    expect(
      readingText(const LppReading(1, LppKind.gps, [42.35, -87.9, 180])),
      '42.35000, -87.90000 · 180 m',
    );
  });
}
