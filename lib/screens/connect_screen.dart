import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/radio_connector.dart';

/// Finds a radio over Bluetooth, USB or Wi-Fi and connects to it.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _ble = <BleTarget>[];
  List<UsbTarget> _usb = const [];
  StreamSubscription<BleTarget>? _scan;
  bool _scanning = false;
  String? _scanError;
  final _host = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startScan();
    _refreshUsb();
  }

  @override
  void dispose() {
    _scan?.cancel();
    _host.dispose();
    super.dispose();
  }

  void _startScan() {
    _scan?.cancel();
    setState(() {
      _ble.clear();
      _scanning = true;
      _scanError = null;
    });
    _scan = ref
        .read(radioConnectorProvider)
        .scanBluetooth()
        .listen(
          (radio) {
            if (mounted) setState(() => _ble.add(radio));
          },
          onError: (Object error) {
            if (mounted) setState(() => _scanError = '$error');
          },
          onDone: () {
            if (mounted) setState(() => _scanning = false);
          },
        );
  }

  Future<void> _refreshUsb() async {
    final connector = ref.read(radioConnectorProvider);
    if (!connector.supportsUsb) return;
    final ports = await connector.listUsb();
    if (mounted) setState(() => _usb = ports);
  }

  void _connect(RadioTarget target) {
    _scan?.cancel();
    setState(() => _scanning = false);
    ref.read(connectionProvider.notifier).connect(target);
  }

  void _connectWifi() {
    final input = _host.text.trim();
    if (input.isEmpty) return;
    final parts = input.split(':');
    final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
    _connect(TcpTarget(host: parts.first, port: port ?? 5000));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionProvider);
    final connecting = state is Connecting;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect a radio')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (state case Disconnected(:final error?))
            _Banner(message: error, color: theme.colorScheme.errorContainer),
          if (state case Connecting(:final target))
            _Banner(
              message: 'Connecting to ${target.label}…',
              color: theme.colorScheme.secondaryContainer,
              busy: true,
            ),
          _Header(
            'Bluetooth',
            trailing: _scanning
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: connecting ? null : _startScan,
                    child: const Text('Scan again'),
                  ),
          ),
          if (_scanError case final error?)
            ListTile(
              leading: const Icon(Icons.bluetooth_disabled),
              title: const Text('Bluetooth scan failed'),
              subtitle: Text(error),
            )
          else if (_ble.isEmpty)
            ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: Text(
                _scanning ? 'Looking for radios…' : 'No radios found',
              ),
            ),
          for (final radio in _ble)
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(radio.label),
              subtitle: radio.rssi == null ? null : Text('${radio.rssi} dBm'),
              enabled: !connecting,
              onTap: () => _connect(radio),
            ),
          if (ref.read(radioConnectorProvider).supportsUsb) ...[
            _Header(
              'USB',
              trailing: TextButton(
                onPressed: connecting ? null : _refreshUsb,
                child: const Text('Refresh'),
              ),
            ),
            if (_usb.isEmpty)
              const ListTile(
                leading: Icon(Icons.usb_off),
                title: Text('No USB devices'),
              ),
            for (final port in _usb)
              ListTile(
                leading: const Icon(Icons.usb),
                title: Text(port.label),
                enabled: !connecting,
                onTap: () => _connect(port),
              ),
          ],
          const _Header('Wi-Fi'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _host,
                    enabled: !connecting,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Radio address',
                      hintText: '192.168.1.50 or host:port',
                    ),
                    onSubmitted: (_) => _connectWifi(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: connecting ? null : _connectWifi,
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ?trailing,
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    this.busy = false,
  });

  final String message;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        if (busy) ...[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(message)),
      ],
    ),
  );
}
