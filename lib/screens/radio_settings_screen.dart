import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/refresh_rate.dart';
import '../app/connection.dart';
import '../radio/radio.dart';
import 'area_screen.dart';
import 'radio_noise_screen.dart';
import 'bots_screen.dart';
import 'app_lock_screen.dart';
import 'repeater_ids_screen.dart';
import 'region_tag_tile.dart';
import 'telemetry_screen.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import '../app/channel_cleanup.dart';
import 'radio_console_screen.dart';
import 'backup_screen.dart';
import 'hop_names_screen.dart';
import 'observer_reach_screen.dart';
import 'identity_key_screen.dart';
import 'blocked_screen.dart';
import '../app/sentinel.dart';
import 'sentinel_screen.dart';
import '../l10n/l10n.dart';
import 'node_journal_screen.dart';
import 'timeline_screen.dart';
import 'path_graph_screen.dart';
import 'repeater_test_screen.dart';
import 'mqtt_screen.dart';

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
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(connectionProvider.notifier).changeRadio(commands);
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on RadioRejected {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioRefusedThatSetting)),
      );
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioDidNotAnswer)),
      );
    } on StateError {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.connectToTheRadioFirst)),
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
        appBar: AppBar(title: Text(context.l10n.radioSettings)),
        body: Center(child: Text(context.l10n.connectToTheRadioToChange)),
      );
    }
    final self = state.radio.self;
    final device = state.radio.device;
    final autoAdd = _autoAdd;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.radioSettings),
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
              title: Text(context.l10n.name),
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
              title: Text(context.l10n.position),
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
              title: Text(context.l10n.sharePositionInAdverts),
              subtitle: Text(context.l10n.othersSeeWhereThisRadioIs),
              value: self.advertLocationPolicy == 1,
              onChanged: (on) =>
                  _change([_otherParams(self, locationPolicy: on ? 1 : 0)]),
            ),

            const _Section('Radio'),
            ListTile(
              leading: const Icon(Icons.settings_input_antenna),
              title: Text(context.l10n.transmitPower),
              subtitle: Text(
                context.l10n.dbmMostThisRadioAllowsDBm(
                  self.txPowerDbm,
                  self.maxTxPowerDbm,
                ),
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
              title: Text(context.l10n.loraSettings),
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
              title: Text(context.l10n.localMeshSettings),
              subtitle: Text(context.l10n.useTheSettingsMostRadiosIn),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AreaScreen()),
              ),
            ),

            const _Section('Contacts'),
            SwitchListTile(
              secondary: const Icon(Icons.person_add_alt),
              title: Text(context.l10n.addNewNodesAutomatically),
              subtitle: Text(context.l10n.whenOffNewNodesWaitUnder),
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
                title: Text(context.l10n.onlyNodesWithin),
                trailing: DropdownButton<int>(
                  value: autoAdd.maxHops.clamp(0, 8),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(context.l10n.anyDistance),
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
              title: Text(context.l10n.batteryAndSensorHistory),
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
              key: const ValueKey('settings-repeater-names'),
              leading: const Icon(Icons.alt_route),
              title: Text(context.l10n.repeaterNames),
              subtitle: Text(context.l10n.repeaterNamesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HopNamesScreen()),
              ),
            ),
            ListTile(
              key: const ValueKey('settings-observer-reach'),
              leading: const Icon(Icons.cell_tower),
              title: Text(context.l10n.observerReach),
              subtitle: Text(context.l10n.observerReachSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ObserverReachScreen(
                    nodeKey: self.publicKey.hex,
                    name: self.name,
                  ),
                ),
              ),
            ),
            ListTile(
              key: const ValueKey('settings-identity-key'),
              leading: const Icon(Icons.key),
              title: Text(context.l10n.identityKey),
              subtitle: Text(context.l10n.identityKeySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const IdentityKeyScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text(context.l10n.backupAndRestore),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(context.l10n.blockedSenders),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BlockedScreen()),
              ),
            ),
            const SpamFilterTile(),
            ListTile(
              key: const ValueKey('settings-sentinel'),
              leading: const Icon(Icons.shield_outlined),
              title: Text(context.l10n.sntTitle),
              subtitle: Text(context.l10n.sntToolSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SentinelPage(
                    sentinel: ref.read(sentinelProvider),
                    selfKey: self.publicKey.hex,
                    selfName: self.name,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.l10n.aboutThisApp),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.l10n.appLock),
              subtitle: Text(context.l10n.fingerprintFaceOrScreenLock),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppLockSettingsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: Text(context.l10n.commandLine),
              subtitle: Text(context.l10n.yourRadioSConsoleAndWi),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RadioConsoleScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(context.l10n.mqttBridge),
              subtitle: Text(context.l10n.mqttBridgeSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MqttScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cell_tower),
              title: Text(context.l10n.nearbyRepeaterTest),
              subtitle: Text(context.l10n.nearbyRepeaterTestSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RepeaterTestScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(context.l10n.pathGraph),
              subtitle: Text(context.l10n.pathGraphSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PathGraphScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(context.l10n.nodeJournal),
              subtitle: Text(context.l10n.nodeJournalSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NodeJournalScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.view_timeline_outlined),
              title: Text(context.l10n.timeline),
              subtitle: Text(context.l10n.timelineSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TimelineScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: Text(context.l10n.repeaterIDs),
              subtitle: Text(context.l10n.whoUsesAnIDAndWhich),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RepeaterIdsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text(context.l10n.autoReplies),
              subtitle: Text(context.l10n.botsAndAwayMessages),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BotsScreen()),
              ),
            ),
            const ChannelCleanupTile(),
            const RegionTagTile(),
            const RefreshRateTile(),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(context.l10n.appearance),
              subtitle: Text(context.l10n.themeAndChatTextSize),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppearanceScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: Text(context.l10n.noiseFloorHistory),
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
                label: Text(context.l10n.rebootRadio),
                onPressed: () async {
                  final sure = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.l10n.rebootTheRadio),
                      content: Text(context.l10n.theRadioRestartsAndTheApp),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(context.l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(context.l10n.reboot),
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
      decoration: InputDecoration(labelText: context.l10n.name),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _save, child: Text(context.l10n.save)),
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
      title: Text(context.l10n.radioPosition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _lat,
            keyboardType: numbers,
            decoration: InputDecoration(
              labelText: context.l10n.latitude,
              hintText: '35.22709',
            ),
          ),
          TextField(
            controller: _lon,
            keyboardType: numbers,
            decoration: InputDecoration(
              labelText: context.l10n.longitude,
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
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(context.l10n.save)),
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
    title: Text(context.l10n.transmitPower),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.dbm3(_value.round()),
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
        Text(context.l10n.higherPowerReachesFurtherButUses),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _value.round()),
        child: Text(context.l10n.save),
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
    title: Text(context.l10n.loraSettings),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.everyRadioYouTalkToMust),
          const SizedBox(height: 12),
          TextField(
            controller: _frequency,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.l10n.frequencyMHz),
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
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _save, child: Text(context.l10n.apply)),
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
