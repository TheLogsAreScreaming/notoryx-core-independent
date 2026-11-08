import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../radio/radio.dart';
import 'area_screen.dart';
import 'radio_noise_screen.dart';
import 'telemetry_screen.dart';
import 'about_screen.dart';
import 'backup_screen.dart';

/// Standard LoRa bandwidths the firmware accepts, in kHz.
const loraBandwidths = [
  7.8,
  10.4,
  15.6,
  20.8,
  31.25,
  41.7,
  62.5,
  125.0,
  250.0,
  500.0,
];

/// The connected radio's own settings: identity, LoRa, contact handling,
/// and device details. Every change is sent to the radio and the screen
/// shows the values the radio reports back.
class RadioSettingsScreen extends ConsumerStatefulWidget {
  const RadioSettingsScreen({super.key});

  @override
  ConsumerState<RadioSettingsScreen> createState() =>
      _RadioSettingsScreenState();
}

class _RadioSettingsScreenState extends ConsumerState<RadioSettingsScreen> {
  AutoAddConfig? _autoAdd;
  BatteryAndStorage? _battery;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExtras());
  }

  Future<void> _loadExtras() async {
    final state = ref.read(connectionProvider);
    if (state is! Connected) return;
    try {
      final autoAdd = await state.sync.autoAddConfig();
      final battery = await state.sync.batteryAndStorage();
      if (mounted) {
        setState(() {
          _autoAdd = autoAdd;
          _battery = battery;
        });
      }
    } on RadioRequestException {
      // Shown as unknown.
    }
  }

  /// Sends [commands] and reports the outcome.
  Future<void> _change(List<RadioCommand> commands, {String? done}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(connectionProvider.notifier).changeRadio(commands);
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on RadioRejected {
      messenger.showSnackBar(
        const SnackBar(content: Text('The radio refused that setting.')),
      );
    } on RadioRequestException {
      messenger.showSnackBar(
        const SnackBar(content: Text('The radio did not answer.')),
      );
    } on StateError {
      messenger.showSnackBar(
        const SnackBar(content: Text('Connect to the radio first.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  SetOtherParams _otherParams(
    SelfInfo self, {
    bool? manualAdd,
    int? locationPolicy,
  }) => SetOtherParams(
    manualAddContacts: manualAdd ?? self.manualAddContacts,
    telemetryModes: self.telemetryModes,
    advertLocationPolicy: locationPolicy ?? self.advertLocationPolicy,
    multiAcks: self.multiAcks,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionProvider);
    if (state is! Connected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Radio settings')),
        body: const Center(
          child: Text('Connect to the radio to change its settings.'),
        ),
      );
    }
    final self = state.radio.self;
    final device = state.radio.device;
    final autoAdd = _autoAdd;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio settings'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          children: [
            const _Section('This radio'),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Name'),
              subtitle: Text(self.name),
              onTap: () async {
                final name = await _askText(
                  context,
                  title: 'Radio name',
                  initial: self.name,
                  maxBytes: 31,
                );
                if (name != null) await _change([SetAdvertName(name)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('Position'),
              subtitle: Text(
                self.latitude == null
                    ? 'Not set'
                    : '${self.latitude!.toStringAsFixed(5)}, '
                          '${self.longitude!.toStringAsFixed(5)}',
              ),
              onTap: () async {
                final position = await showDialog<(double, double)>(
                  context: context,
                  builder: (_) => _PositionDialog(
                    latitude: self.latitude,
                    longitude: self.longitude,
                  ),
                );
                if (position != null) {
                  await _change([
                    SetAdvertPosition(
                      latitude: position.$1,
                      longitude: position.$2,
                    ),
                  ]);
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.share_location_outlined),
              title: const Text('Share position in adverts'),
              subtitle: const Text('Others see where this radio is on a map'),
              value: self.advertLocationPolicy == 1,
              onChanged: (on) =>
                  _change([_otherParams(self, locationPolicy: on ? 1 : 0)]),
            ),

            const _Section('Radio'),
            ListTile(
              leading: const Icon(Icons.settings_input_antenna),
              title: const Text('Transmit power'),
              subtitle: Text(
                '${self.txPowerDbm} dBm (most this radio allows: '
                '${self.maxTxPowerDbm} dBm)',
              ),
              onTap: () async {
                final dbm = await showDialog<int>(
                  context: context,
                  builder: (_) => _PowerDialog(
                    current: self.txPowerDbm,
                    max: self.maxTxPowerDbm,
                  ),
                );
                if (dbm != null) await _change([SetTxPower(dbm)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: const Text('LoRa settings'),
              subtitle: Text(_lora(self)),
              onTap: () async {
                final params = await showDialog<SetRadioParams>(
                  context: context,
                  builder: (_) => _LoraDialog(
                    self: self,
                    clientRepeat: device.clientRepeat,
                  ),
                );
                if (params != null) {
                  await _change([params], done: 'LoRa settings changed');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Local mesh settings'),
              subtitle: const Text(
                'Use the settings most radios in an area use',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AreaScreen()),
              ),
            ),

            const _Section('Contacts'),
            SwitchListTile(
              secondary: const Icon(Icons.person_add_alt),
              title: const Text('Add new nodes automatically'),
              subtitle: const Text(
                'When off, new nodes wait under "Heard nearby" for you to add',
              ),
              value: !self.manualAddContacts,
              onChanged: (on) => _change([_otherParams(self, manualAdd: !on)]),
            ),
            if (self.manualAddContacts && autoAdd != null) ...[
              for (final (flag, label) in const [
                (AutoAddConfig.companions, 'Still add people automatically'),
                (AutoAddConfig.repeaters, 'Still add repeaters automatically'),
                (AutoAddConfig.roomServers, 'Still add rooms automatically'),
                (AutoAddConfig.sensors, 'Still add sensors automatically'),
                (
                  AutoAddConfig.replaceOldest,
                  'When full, replace the oldest non-favourite',
                ),
              ])
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: 16),
                  title: Text(label),
                  value: autoAdd.has(flag),
                  onChanged: (on) async {
                    final next = autoAdd.withFlag(flag, on);
                    await _change([SetAutoAddConfig(next)]);
                    setState(() => _autoAdd = next);
                  },
                ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: const Text('Only nodes within'),
                trailing: DropdownButton<int>(
                  value: autoAdd.maxHops.clamp(0, 8),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('any distance'),
                    ),
                    for (var h = 1; h <= 8; h++)
                      DropdownMenuItem(
                        value: h,
                        child: Text(h == 1 ? 'direct only' : '${h - 1} hops'),
                      ),
                  ],
                  onChanged: (hops) async {
                    if (hops == null) return;
                    final next = AutoAddConfig(
                      flags: autoAdd.flags,
                      maxHops: hops,
                    );
                    await _change([SetAutoAddConfig(next)]);
                    setState(() => _autoAdd = next);
                  },
                ),
              ),
            ],

            const _Section('About this radio'),
            _Info('Model', device.manufacturer ?? 'Unknown'),
            _Info(
              'Firmware',
              '${device.firmwareVersion ?? 'Unknown'} '
                  '(protocol ${device.firmwareVersionCode})',
            ),
            if (device.buildDate case final date? when date.isNotEmpty)
              _Info('Built', date),
            _Info(
              'Capacity',
              '${device.maxContacts ?? '?'} contacts, '
                  '${device.maxChannels ?? '?'} channels',
            ),
            if (_battery case final battery?) ...[
              _Info(
                'Battery',
                '${(battery.millivolts / 1000).toStringAsFixed(2)} V',
              ),
              if (battery.usedKb != null && battery.totalKb != null)
                _Info(
                  'Storage',
                  '${battery.usedKb} of ${battery.totalKb} KB used',
                ),
            ],
            ListTile(
              leading: const Icon(Icons.sensors),
              title: const Text('Battery and sensor history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TelemetryScreen(
                    nodeKey: self.publicKey.hex,
                    name: self.name,
                    isSelf: true,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup and restore'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About this app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: const Text('Noise floor history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RadioNoiseScreen(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: OutlinedButton.icon(
                icon: Icon(Icons.restart_alt, color: theme.colorScheme.error),
                label: const Text('Reboot radio'),
                onPressed: () async {
                  final sure = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reboot the radio?'),
                      content: const Text(
                        'The radio restarts and the app reconnects to it '
                        'automatically.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Reboot'),
                        ),
                      ],
                    ),
                  );
                  if (sure == true) await state.sync.reboot();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _lora(SelfInfo s) {
    String trim(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    return '${s.frequencyMhz.toStringAsFixed(3)} MHz · BW ${trim(s.bandwidthKhz)} kHz'
        ' · SF${s.spreadingFactor} · CR 4/${s.codingRate}';
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(label),
    trailing: Text(value, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// Asks for a short name, trimmed and cut to [maxBytes] of UTF-8.
Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String initial,
  required int maxBytes,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _NameDialog(title: title, initial: initial, maxBytes: maxBytes),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.maxBytes,
  });

  final String title;
  final String initial;
  final int maxBytes;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      inputFormatters: [_Utf8LimitFormatter(widget.maxBytes)],
      decoration: const InputDecoration(labelText: 'Name'),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

/// Stops typing past a UTF-8 byte limit, as the radio stores bytes.
class _Utf8LimitFormatter extends TextInputFormatter {
  _Utf8LimitFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) => _utf8Length(next.text) <= maxBytes ? next : old;

  static int _utf8Length(String s) {
    var n = 0;
    for (final r in s.runes) {
      n += r < 0x80
          ? 1
          : r < 0x800
          ? 2
          : r < 0x10000
          ? 3
          : 4;
    }
    return n;
  }
}

class _PositionDialog extends StatefulWidget {
  const _PositionDialog({this.latitude, this.longitude});

  final double? latitude;
  final double? longitude;

  @override
  State<_PositionDialog> createState() => _PositionDialogState();
}

class _PositionDialogState extends State<_PositionDialog> {
  late final _lat = TextEditingController(
    text: widget.latitude?.toString() ?? '',
  );
  late final _lon = TextEditingController(
    text: widget.longitude?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  void _save() {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      setState(
        () => _error =
            'Use decimal degrees: latitude −90 to 90, '
            'longitude −180 to 180.',
      );
      return;
    }
    Navigator.pop(context, (lat, lon));
  }

  @override
  Widget build(BuildContext context) {
    const numbers = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );
    return AlertDialog(
      title: const Text('Radio position'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _lat,
            keyboardType: numbers,
            decoration: const InputDecoration(
              labelText: 'Latitude',
              hintText: '35.22709',
            ),
          ),
          TextField(
            controller: _lon,
            keyboardType: numbers,
            decoration: const InputDecoration(
              labelText: 'Longitude',
              hintText: '-80.84313',
            ),
          ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _PowerDialog extends StatefulWidget {
  const _PowerDialog({required this.current, required this.max});

  final int current;
  final int max;

  @override
  State<_PowerDialog> createState() => _PowerDialogState();
}

class _PowerDialogState extends State<_PowerDialog> {
  // The firmware accepts -9 dBm up to the radio's own maximum.
  static const _min = -9;
  late double _value = widget.current.clamp(_min, widget.max).toDouble();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Transmit power'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_value.round()} dBm',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Slider(
          min: _min.toDouble(),
          max: widget.max.toDouble(),
          divisions: widget.max - _min,
          value: _value,
          label: '${_value.round()} dBm',
          onChanged: (v) => setState(() => _value = v),
        ),
        const Text(
          'Higher power reaches further but uses more battery. Stay within '
          'the limits for your country and licence.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _value.round()),
        child: const Text('Save'),
      ),
    ],
  );
}

class _LoraDialog extends StatefulWidget {
  const _LoraDialog({required this.self, this.clientRepeat});

  final SelfInfo self;
  final bool? clientRepeat;

  @override
  State<_LoraDialog> createState() => _LoraDialogState();
}

class _LoraDialogState extends State<_LoraDialog> {
  late final _frequency = TextEditingController(
    text: widget.self.frequencyMhz.toStringAsFixed(3),
  );
  late double _bandwidth = loraBandwidths.firstWhere(
    (b) => (b - widget.self.bandwidthKhz).abs() < 0.1,
    orElse: () => 62.5,
  );
  late int _sf = widget.self.spreadingFactor.clamp(5, 12);
  late int _cr = widget.self.codingRate.clamp(5, 8);
  String? _error;

  @override
  void dispose() {
    _frequency.dispose();
    super.dispose();
  }

  void _save() {
    final mhz = double.tryParse(_frequency.text.trim());
    // The firmware's accepted range: 150 MHz to 2.5 GHz.
    if (mhz == null || mhz < 150 || mhz > 2500) {
      setState(() => _error = 'Frequency must be between 150 and 2500 MHz.');
      return;
    }
    Navigator.pop(
      context,
      SetRadioParams(
        frequencyMhz: mhz,
        bandwidthKhz: _bandwidth,
        spreadingFactor: _sf,
        codingRate: _cr,
        clientRepeat: widget.clientRepeat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('LoRa settings'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Every radio you talk to must use the same settings. A wrong value '
            'cuts this radio off from the mesh until it’s changed back.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _frequency,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Frequency (MHz)'),
          ),
          _picker<double>('Bandwidth', _bandwidth, {
            for (final b in loraBandwidths) b: '$b kHz',
          }, (v) => setState(() => _bandwidth = v)),
          _picker<int>('Spreading factor', _sf, {
            for (var i = 5; i <= 12; i++) i: 'SF$i',
          }, (v) => setState(() => _sf = v)),
          _picker<int>('Coding rate', _cr, {
            for (var i = 5; i <= 8; i++) i: '4/$i',
          }, (v) => setState(() => _cr = v)),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Apply')),
    ],
  );

  Widget _picker<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> onChanged,
  ) => Row(
    children: [
      Expanded(child: Text(label)),
      DropdownButton<T>(
        value: value,
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ],
  );
}
