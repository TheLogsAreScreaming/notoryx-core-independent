import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/mqtt_bridge.dart';
import 'package:notoryx_core/radio/radio.dart';

void main() {
  test('off and empty by default; bad data stays off', () {
    expect(const MqttConfig().enabled, isFalse);
    expect(MqttConfig.fromJson('junk').enabled, isFalse);
    expect(const MqttConfig().usable, isFalse);
  });

  test('settings survive saving, and never include a password', () {
    const c = MqttConfig(
      enabled: true,
      host: 'mqtt.example.org',
      port: 8883,
      tls: true,
      username: 'sam',
      topic: 'mesh/{radio}/rx',
    );
    final json = c.toJson();
    expect(json, isNot(contains('password')));
    final back = MqttConfig.fromJson(json);
    expect(back.port, 8883);
    expect(back.tls, isTrue);
    expect(mqttTopic(back, 'abcd'), 'mesh/abcd/rx');
  });

  test('a packet becomes JSON with its route, type and hops', () {
    final rx = RxLog(
      snr: 5.25,
      rssi: -97,
      packet: [(5 << 2) | 1, 2, 0xAA, 0xBB, 0x11, 0x22, 0x33],
    );
    final j = jsonDecode(
      packetJson(rx, radioKey: 'ff', at: DateTime.utc(2026, 11, 12)),
    ) as Map<String, Object?>;
    expect(j['observer'], 'ff');
    expect(j['snr'], 5.25);
    expect(j['rssi'], -97);
    expect(j['raw'], startsWith('1502aabb'));
    expect(j['route'], 'flood');
    expect(j['type'], 'groupText');
    expect(j['hops'], ['aa', 'bb']);
    expect(j['time'], '2026-11-12T00:00:00.000Z');
  });
}
