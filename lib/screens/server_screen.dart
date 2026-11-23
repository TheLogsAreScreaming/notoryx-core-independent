import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'region_setup_screen.dart';

import '../app/connection.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'antenna_hunt_screen.dart';
import 'conversation_screen.dart';
import 'node_avatar.dart';
import 'node_details.dart';
import 'repeater_tools.dart';
import 'server_history_card.dart';
import '../app/server_history.dart';
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
  int _checks = 0;
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
            SnackBar(
              content: Text(context.l10n.noReplyCheckThePasswordServers),
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
      final radioKey = ref.read(radioKeyProvider);
      if (status != null && radioKey != null) {
        await keepServerCheck(
          ref.read(storeProvider),
          radioKey,
          widget.node.publicKey,
          status,
          DateTime.now(),
        );
        _checks++;
      }
      if (!mounted) return;
      setState(() {
        _status = status ?? _status;
        _statusNote = status == null ? context.l10n.noReplyFromServer : null;
      });
    } on RadioRequestException {
      if (mounted) {
        setState(() => _statusNote = context.l10n.radioCouldNotSendRequest);
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
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      await sync.sendCommand(_key, text);
      _command.clear();
    } on ArgumentError {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.thatCommandIsTooLong)),
      );
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotSendIt)),
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
              NodeAvatar(
                publicKey: widget.node.publicKey,
                name: widget.node.name,
                type: widget.node.type,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${nodeKind(widget.node.type, context.l10n)} · '
                  '${routeText(widget.node.outPathLength, context.l10n)}',
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
                        Expanded(
                          child: Text(context.l10n.loggedInAs(role.label)),
                        ),
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
                              ? context.l10n.roomPasswordHint
                              : context.l10n.adminOrGuestPassword,
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
                          child: Text(
                            context.l10n.loggingInOrLogIn('$_loggingIn'),
                          ),
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
                            context.l10n.getStatusOrRefresh(
                              '${_status == null}',
                            ),
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
          if (radioKey != null)
            ServerHistoryCard(
              radioKey: radioKey,
              nodeKey: widget.node.publicKey,
              version: _checks,
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
    _Stat(
      context.l10n.infoBattery,
      '${(s.batteryMillivolts / 1000).toStringAsFixed(2)} V',
    ),
    _Stat(context.l10n.statUpFor, _duration(s.upTimeSeconds)),
    _Stat(
      context.l10n.statLastSignal,
      '${s.lastRssi} dBm · SNR ${s.lastSnr.toStringAsFixed(1)} dB',
    ),
    _Stat(context.l10n.noiseFloor, '${s.noiseFloor} dBm'),
    _Stat(
      context.l10n.statPackets,
      context.l10n.statPacketsValue(s.packetsReceived, s.packetsSent),
    ),
    _Stat(
      context.l10n.statFlood,
      context.l10n.statInOut(s.receivedFlood, s.sentFlood),
    ),
    _Stat(
      context.l10n.statDirect,
      context.l10n.statInOut(s.receivedDirect, s.sentDirect),
    ),
    _Stat(
      context.l10n.statDuplicates,
      '${s.floodDuplicates + s.directDuplicates}',
    ),
    _Stat(context.l10n.statTransmitting, _duration(s.airTimeSeconds)),
    if (s.receiveAirTimeSeconds case final rx?)
      _Stat(context.l10n.statReceiving, _duration(rx)),
    _Stat(context.l10n.statSendQueue, '${s.txQueue}'),
    if (s.posts case final posts?) _Stat(context.l10n.statPosts, '$posts'),
    if (s.receiveErrors case final e?)
      _Stat(context.l10n.statReceiveErrors, '$e'),
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
