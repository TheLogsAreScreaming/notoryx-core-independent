import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/radio_connector.dart';
import 'appearance_screen.dart';
import 'backup_screen.dart';
import 'connection_log_screen.dart';
import 'field_guide_screen.dart';
import '../l10n/l10n.dart';
import 'about_screen.dart';

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
  bool _showAll = false;
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
        .scanBluetooth(all: _showAll)
        .listen(
          (radio) {
            if (!mounted) return;
            setState(() {
              _ble.add(radio);
              // Radios first, then the strongest signal.
              _ble.sort((a, b) {
                if (a.isMeshCore != b.isMeshCore) return a.isMeshCore ? -1 : 1;
                return (b.rssi ?? -999).compareTo(a.rssi ?? -999);
              });
            });
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _scanError = '$error';
                _scanning = false;
              });
            }
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
    ref.read(connectionProvider.notifier)
      ..stopViewingSaved()
      ..connect(target);
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
    final saved = ref.watch(savedRadiosProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.connectARadio),
        actions: [
          const ConnectionLogButton(),
          IconButton(
            tooltip: context.l10n.about,
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (state
              case Disconnected(:final error?) || ViewingSaved(:final error?))
            _Banner(message: error, color: theme.colorScheme.errorContainer),
          if (state case Connecting(:final target))
            _Banner(
              message: 'Connecting to ${target.label}…',
              color: theme.colorScheme.secondaryContainer,
              busy: true,
            ),
          for (final radio in saved.where(
            (r) => state is! ViewingSaved || state.radioKey != r.publicKey,
          ))
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text('Open saved chats: ${radio.name}'),
              subtitle: Text(context.l10n.readChatsContactsAndTheMap),
              enabled: !connecting,
              onTap: () {
                ref
                    .read(connectionProvider.notifier)
                    .viewSaved(
                      radioKey: radio.publicKey,
                      radioName: radio.name,
                    );
                Navigator.of(context).maybePop();
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(context.l10n.fieldGuide),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FieldGuideScreen(),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.palette_outlined, size: 18),
                  label: Text(context.l10n.appearance),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AppearanceScreen(),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.backup_outlined, size: 18),
                  label: Text(context.l10n.backupAndRestore),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BackupScreen(),
                    ),
                  ),
                ),
              ],
            ),
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
                    child: Text(context.l10n.scanAgain),
                  ),
          ),
          if (_scanError case final error?)
            ListTile(
              leading: const Icon(Icons.bluetooth_disabled),
              title: const Text('Can\u2019t scan for radios'),
              subtitle: Text(error),
            )
          else if (_ble.isEmpty)
            ListTile(
              leading: const Icon(Icons.bluetooth_searching),
              title: Text(
                _scanning ? 'Looking for radios…' : 'No radios found',
              ),
              subtitle: _scanning
                  ? null
                  : const Text(
                      'Check the radio is on and in Bluetooth mode, and not '
                      'connected to another app or phone: a radio stops '
                      'advertising while something is connected to it.',
                    ),
            ),
          for (final radio in _ble)
            ListTile(
              leading: Icon(
                radio.isMeshCore ? Icons.bluetooth : Icons.device_unknown,
              ),
              title: Text(radio.label),
              subtitle: radio.rssi == null ? null : Text('${radio.rssi} dBm'),
              enabled: !connecting,
              onTap: () => _connect(radio),
            ),
          SwitchListTile(
            title: Text(context.l10n.showAllBluetoothDevices),
            subtitle: const Text('For a radio that doesn\u2019t show up'),
            value: _showAll,
            onChanged: connecting
                ? null
                : (value) {
                    setState(() => _showAll = value);
                    _startScan();
                  },
          ),
          if (ref.read(radioConnectorProvider).supportsUsb) ...[
            _Header(
              'USB',
              trailing: TextButton(
                onPressed: connecting ? null : _refreshUsb,
                child: Text(context.l10n.refresh),
              ),
            ),
            if (_usb.isEmpty)
              ListTile(
                leading: Icon(Icons.usb_off),
                title: Text(context.l10n.noUSBDevices),
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
                    decoration: InputDecoration(
                      labelText: context.l10n.radioAddress,
                      hintText: context.l10n.t192168150OrHost,
                    ),
                    onSubmitted: (_) => _connectWifi(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: connecting ? null : _connectWifi,
                  child: Text(context.l10n.connect),
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
