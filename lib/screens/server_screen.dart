import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'region_setup_screen.dart';

import '../app/connection.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'antenna_hunt_screen.dart';
import 'conversation_screen.dart';
import 'node_details.dart';
import 'repeater_tools.dart';
import 'telemetry_screen.dart';
import '../l10n/l10n.dart';

/// A repeater or room server: log in, check its status, open the room, and
/// (as admin) use its console.
class ServerScreen extends ConsumerStatefulWidget {
  const ServerScreen({required this.node, super.key});

  final NodeSummary node;

  @override
  ConsumerState<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends ConsumerState<ServerScreen> {
  final _password = TextEditingController();
  final _command = TextEditingController();
  bool _loggingIn = false;
  bool _loadingStatus = false;
  bool _sending = false;
  ServerStatus? _status;
  String? _statusNote;

  PublicKey get _key => PublicKey.fromHex(widget.node.publicKey);
  bool get _isRoom => widget.node.type == NodeType.room;

  @override
  void dispose() {
    _password.dispose();
    _command.dispose();
    super.dispose();
  }

  MeshSync? _sync() {
    final state = ref.read(connectionProvider);
    if (state is Connected) return state.sync;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.connectToTheRadioFirst)),
    );
    return null;
  }

  Future<void> _login() async {
    final sync = _sync();
    if (sync == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loggingIn = true);
    try {
      final result = await sync.login(_key, _password.text);
      if (!mounted) return;
      switch (result) {
        case LoggedIn(:final role):
          ref
              .read(serverRolesProvider.notifier)
              .set(widget.node.publicKey, role);
          _password.clear();
        case LoginRefused():
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.loginRefused)),
          );
        case LoginNoReply():
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No reply. Check the password (servers stay silent when it’s '
                'wrong) and that the server is in range.',
              ),
            ),
          );
      }
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.theRadioCouldNotSendThe)),
      );
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _logout() async {
    final sync = _sync();
    if (sync == null) return;
    try {
      await sync.logout(_key);
    } on RadioRequestException {
      // Forget the role either way.
    }
    ref.read(serverRolesProvider.notifier).set(widget.node.publicKey, null);
  }

  Future<void> _refreshStatus() async {
    final sync = _sync();
    if (sync == null) return;
    setState(() {
      _loadingStatus = true;
      _statusNote = null;
    });
    try {
      final status = await sync.requestStatus(_key);
      if (!mounted) return;
      setState(() {
        _status = status ?? _status;
        _statusNote = status == null ? 'No reply from the server.' : null;
      });
    } on RadioRequestException {
      if (mounted) {
        setState(() => _statusNote = 'The radio could not send the request.');
      }
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _sendCommand() async {
    final text = _command.text.trim();
    final sync = _sync();
    if (text.isEmpty || sync == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await sync.sendCommand(_key, text);
      _command.clear();
    } on ArgumentError {
      messenger.showSnackBar(
        SnackBar(content: Text('That command is too long.')),
      );
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text('The radio could not send it.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(serverRolesProvider)[widget.node.publicKey];
    final radioKey = ref.watch(radioKeyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.node.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(child: Icon(nodeIcon(widget.node.type))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${nodeKind(widget.node.type)} · '
                  '${routeText(widget.node.outPathLength)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Login
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: role != null
                  ? Row(
                      children: [
                        const Icon(Icons.verified_user_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Logged in as ${role.label}')),
                        TextButton(
                          onPressed: _logout,
                          child: Text(context.l10n.logOut),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.logIn,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRoom
                              ? 'Use the room’s password, or leave it empty '
                                    'if the room allows guests.'
                              : 'Use the admin or guest password.',
                        ),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          enabled: !_loggingIn,
                          decoration: InputDecoration(
                            labelText: context.l10n.password,
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loggingIn ? null : _login,
                          child: Text(_loggingIn ? 'Logging in…' : 'Log in'),
                        ),
                      ],
                    ),
            ),
          ),

          if (_isRoom)
            Card(
              child: ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: Text(context.l10n.openTheRoom),
                subtitle: Text(context.l10n.postsArriveAfterYouLogIn),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ConversationScreen(
                      thread: Threads.direct(widget.node.publicKey),
                      title: widget.node.name,
                    ),
                  ),
                ),
              ),
            ),

          // Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.status,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (_loadingStatus)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton(
                          onPressed: _refreshStatus,
                          child: Text(
                            _status == null ? 'Get status' : 'Refresh',
                          ),
                        ),
                    ],
                  ),
                  if (_statusNote case final note?) Text(note),
                  if (_status case final s?) ..._statusRows(s),
                ],
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.sensors),
              title: Text(context.l10n.telemetry),
              subtitle: Text(context.l10n.batteryAndSensorsOverTime),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TelemetryScreen(
                    nodeKey: widget.node.publicKey,
                    name: widget.node.name,
                    type: widget.node.type,
                  ),
                ),
              ),
            ),
          ),

          RepeaterPingCard(publicKey: widget.node.publicKey),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_input_antenna),
              title: Text(context.l10n.antennaHunt),
              subtitle: Text(context.l10n.clicksFasterAsThisOneGets),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AntennaHuntScreen(
                    publicKey: widget.node.publicKey,
                    name: widget.node.name,
                  ),
                ),
              ),
            ),
          ),

          // Console
          if (role == ServerRole.admin && radioKey != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.console,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    RepeaterAdminTools(
                      radioKey: radioKey,
                      server: _key,
                      lines:
                          ref
                              .watch(
                                consoleProvider((
                                  radioKey: radioKey,
                                  thread: Threads.direct(widget.node.publicKey),
                                )),
                              )
                              .value ??
                          const [],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.map_outlined),
                        label: Text(context.l10n.regionSetup),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RegionSetupScreen(
                              send: (c) async =>
                                  await _sync()?.sendCommand(_key, c),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _Console(
                      radioKey: radioKey,
                      thread: Threads.direct(widget.node.publicKey),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _command,
                            enabled: !_sending,
                            autocorrect: false,
                            style: const TextStyle(fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: context.l10n.commandEGVerOrClock,
                            ),
                            onSubmitted: (_) => _sendCommand(),
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.sendCommand,
                          onPressed: _sending ? null : _sendCommand,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _statusRows(ServerStatus s) => [
    _Stat('Battery', '${(s.batteryMillivolts / 1000).toStringAsFixed(2)} V'),
    _Stat('Up for', _duration(s.upTimeSeconds)),
    _Stat(
      'Last signal',
      '${s.lastRssi} dBm · SNR ${s.lastSnr.toStringAsFixed(1)} dB',
    ),
    _Stat('Noise floor', '${s.noiseFloor} dBm'),
    _Stat('Packets', '${s.packetsReceived} received · ${s.packetsSent} sent'),
    _Stat('Flood', '${s.receivedFlood} in · ${s.sentFlood} out'),
    _Stat('Direct', '${s.receivedDirect} in · ${s.sentDirect} out'),
    _Stat('Duplicates dropped', '${s.floodDuplicates + s.directDuplicates}'),
    _Stat('Transmitting', _duration(s.airTimeSeconds)),
    if (s.receiveAirTimeSeconds case final rx?)
      _Stat('Receiving', _duration(rx)),
    _Stat('Send queue', '${s.txQueue}'),
    if (s.posts case final posts?) _Stat('Posts', '$posts'),
    if (s.receiveErrors case final e?) _Stat('Receive errors', '$e'),
  ];

  static String _duration(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(value),
      ],
    ),
  );
}

class _Console extends ConsumerWidget {
  const _Console({required this.radioKey, required this.thread});

  final String radioKey;
  final String thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines =
        ref
            .watch(consoleProvider((radioKey: radioKey, thread: thread)))
            .value ??
        const [];
    if (lines.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(context.l10n.commandsAndRepliesShowHere),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        reverse: true,
        shrinkWrap: true,
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final m = lines[lines.length - 1 - i];
          return SelectableText(
            m.outgoing ? '> ${m.body}' : m.body,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: m.outgoing ? Theme.of(context).colorScheme.primary : null,
            ),
          );
        },
      ),
    );
  }
}
