import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/mqtt_bridge.dart';
import '../l10n/l10n.dart';

/// Sets up the MQTT bridge.
class MqttScreen extends ConsumerStatefulWidget {
  const MqttScreen({super.key});

  @override
  ConsumerState<MqttScreen> createState() => _MqttScreenState();
}

class _MqttScreenState extends ConsumerState<MqttScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _topic = TextEditingController();
  bool _enabled = false;
  bool _tls = false;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _password, _topic]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(MqttConfig c) {
    _loaded = true;
    _enabled = c.enabled;
    _tls = c.tls;
    _host.text = c.host;
    _port.text = '${c.port}';
    _user.text = c.username;
    _topic.text = c.topic;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final ok = await ref
        .read(mqttSettingsProvider.notifier)
        .save(
          MqttConfig(
            enabled: _enabled,
            host: _host.text.trim(),
            port: int.tryParse(_port.text) ?? 1883,
            tls: _tls,
            username: _user.text.trim(),
            topic: _topic.text.trim().isEmpty
                ? 'notoryx/{radio}/packets'
                : _topic.text.trim(),
          ),
          password: _password.text.isEmpty ? null : _password.text,
        );
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.mqttSaved : l10n.mqttPasswordNotSaved)),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool secret = false,
    String? help,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: TextField(
      controller: c,
      obscureText: secret,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        helperText: help,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(mqttSettingsProvider).value;
    if (config != null && !_loaded) _load(config);
    final status = ref.watch(mqttStatusProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mqttBridge)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.mqttWarning),
          ),
          SwitchListTile(
            title: Text(l10n.mqttEnabled),
            subtitle: Text(
              status.error != null
                  ? l10n.mqttError(status.error!)
                  : status.connected
                  ? l10n.mqttConnected(status.sent)
                  : l10n.mqttNotConnected,
            ),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          _field(_host, l10n.mqttHost),
          _field(_port, l10n.mqttPort, type: TextInputType.number),
          SwitchListTile(
            title: Text(l10n.mqttTls),
            value: _tls,
            onChanged: (v) => setState(() => _tls = v),
          ),
          _field(_user, l10n.mqttUsername),
          _field(_password, l10n.mqttPassword, secret: true),
          _field(_topic, l10n.mqttTopic, help: l10n.mqttTopicHelp('{radio}')),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(onPressed: _save, child: Text(l10n.save)),
          ),
        ],
      ),
    );
  }
}
