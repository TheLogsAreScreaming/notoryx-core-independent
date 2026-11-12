/// MQTT bridge: sends every packet the radio hears, as JSON, to an MQTT
/// broker the person sets up. Off by default.
///
/// What goes out is what the radio heard over the air: encrypted message
/// payloads it can't read, plus public adverts (names, keys and any
/// positions people chose to share). It never sends the app's own messages
/// in readable form.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../radio/radio.dart';
import 'connection.dart';

const mqttSetting = 'mqtt_bridge';
const _passwordKey = 'notoryx_mqtt_password';

final class MqttConfig {
  const MqttConfig({
    this.enabled = false,
    this.host = '',
    this.port = 1883,
    this.tls = false,
    this.username = '',
    this.topic = 'notoryx/{radio}/packets',
  });

  factory MqttConfig.fromJson(String? raw) {
    if (raw == null) return const MqttConfig();
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      return MqttConfig(
        enabled: j['enabled'] == true,
        host: (j['host'] as String?) ?? '',
        port: (j['port'] as int?) ?? 1883,
        tls: j['tls'] == true,
        username: (j['username'] as String?) ?? '',
        topic: (j['topic'] as String?) ?? 'notoryx/{radio}/packets',
      );
    } on Object {
      return const MqttConfig();
    }
  }

  final bool enabled;
  final String host;
  final int port;
  final bool tls;
  final String username;

  /// `{radio}` becomes the radio's public key.
  final String topic;

  bool get usable => host.trim().isNotEmpty && port > 0 && port < 65536;

  String toJson() => jsonEncode({
    'enabled': enabled,
    'host': host,
    'port': port,
    'tls': tls,
    'username': username,
    'topic': topic,
  });
}

/// The topic for [radioKey].
String mqttTopic(MqttConfig c, String radioKey) =>
    c.topic.replaceAll('{radio}', radioKey);

/// One heard packet as JSON.
String packetJson(RxLog rx, {required String radioKey, required DateTime at}) {
  final header = PacketHeader.parse(rx.packet);
  return jsonEncode({
    'time': at.toUtc().toIso8601String(),
    'observer': radioKey,
    'snr': rx.snr,
    'rssi': rx.rssi,
    'raw': toHex(rx.packet),
    if (header != null) ...{
      'route': header.route.name,
      'type': header.payload.name,
      'hops': header.hops,
    },
  });
}

/// Where packets go. Tests replace it.
abstract interface class MqttSink {
  Future<void> connect(MqttConfig config, String password, String clientId);
  void publish(String topic, String json);
  Future<void> close();
  bool get connected;
}

final class BrokerSink implements MqttSink {
  MqttServerClient? _client;

  @override
  bool get connected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  Future<void> connect(MqttConfig c, String password, String clientId) async {
    final client = MqttServerClient.withPort(c.host.trim(), clientId, c.port)
      ..secure = c.tls
      ..keepAlivePeriod = 60
      ..autoReconnect = true
      ..logging(on: false);
    _client = client;
    await client.connect(
      c.username.isEmpty ? null : c.username,
      password.isEmpty ? null : password,
    );
  }

  @override
  void publish(String topic, String json) {
    final client = _client;
    if (client == null || !connected) return;
    final payload = MqttClientPayloadBuilder()..addUTF8String(json);
    client.publishMessage(topic, MqttQos.atMostOnce, payload.payload!);
  }

  @override
  Future<void> close() async => _client?.disconnect();
}

final mqttSinkProvider = Provider<MqttSink Function()>((ref) => BrokerSink.new);

/// Saved settings, with the password in secure storage when the device has
/// it.
class MqttSettings extends AsyncNotifier<MqttConfig> {
  static const _storage = FlutterSecureStorage();

  @override
  Future<MqttConfig> build() async =>
      MqttConfig.fromJson(await ref.read(storeProvider).setting(mqttSetting));

  Future<String> password() async {
    try {
      return await _storage.read(key: _passwordKey) ?? '';
    } on Object {
      return '';
    }
  }

  /// Saves [c], and [password] when given. Returns false if the password
  /// couldn't be stored securely on this device.
  Future<bool> save(MqttConfig c, {String? password}) async {
    await ref.read(storeProvider).saveSetting(mqttSetting, c.toJson());
    state = AsyncData(c);
    if (password == null) return true;
    try {
      await _storage.write(key: _passwordKey, value: password);
      return true;
    } on Object {
      return false;
    }
  }
}

final mqttSettingsProvider = AsyncNotifierProvider<MqttSettings, MqttConfig>(
  MqttSettings.new,
);

final class MqttStatus {
  const MqttStatus({this.connected = false, this.sent = 0, this.error});

  final bool connected;
  final int sent;
  final String? error;
}

final mqttStatusProvider = NotifierProvider<MqttStatusNotifier, MqttStatus>(
  MqttStatusNotifier.new,
);

class MqttStatusNotifier extends Notifier<MqttStatus> {
  @override
  MqttStatus build() => const MqttStatus();

  // ignore: use_setters_to_change_properties
  void set(MqttStatus s) => state = s;
}

/// Runs the bridge while a radio is connected and it's switched on.
final mqttBridgeProvider = Provider<void>((ref) {
  final connection = ref.watch(connectionProvider);
  final config = ref.watch(mqttSettingsProvider).value;
  final status = ref.read(mqttStatusProvider.notifier);
  if (connection is! Connected || config == null || !config.enabled) {
    Future.microtask(() => status.set(const MqttStatus()));
    return;
  }
  if (!config.usable) return;
  final sink = ref.read(mqttSinkProvider)();
  final key = connection.radio.key;
  final topic = mqttTopic(config, key);
  var sent = 0;
  StreamSubscription<RxLog>? sub;
  var closed = false;
  unawaited(() async {
    try {
      final password = await ref.read(mqttSettingsProvider.notifier).password();
      await sink.connect(
        config,
        password,
        'notoryx-${key.substring(0, 12)}-${pid % 10000}',
      );
      if (closed) return;
      status.set(MqttStatus(connected: sink.connected));
      sub = connection.sync.heard.listen((rx) {
        if (!sink.connected) return;
        sink.publish(topic, packetJson(rx, radioKey: key, at: DateTime.now()));
        sent++;
        status.set(MqttStatus(connected: true, sent: sent));
      });
    } on Object catch (e) {
      ref.read(connectionLogProvider).add('MQTT: $e');
      status.set(MqttStatus(error: '$e'));
    }
  }());
  ref.onDispose(() {
    closed = true;
    unawaited(sub?.cancel());
    unawaited(sink.close());
  });
});
