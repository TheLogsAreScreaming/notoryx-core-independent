import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/channel_directory.dart';
import '../app/connection.dart';
import '../app/mesh_links.dart';
import '../data/data.dart';
import '../presets/area_presets_provider.dart';
import 'manage_actions.dart';
import '../l10n/l10n.dart';

/// Channels to join: ones heard on air, ones for this area, and common
/// public ones. Any other #name can be checked and joined too.
class ChannelDirectoryScreen extends ConsumerStatefulWidget {
  const ChannelDirectoryScreen({super.key});

  @override
  ConsumerState<ChannelDirectoryScreen> createState() =>
      _ChannelDirectoryScreenState();
}

class _ChannelDirectoryScreenState
    extends ConsumerState<ChannelDirectoryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radioKey = ref.watch(radioKeyProvider);
    final connected = ref.watch(connectionProvider) is Connected;
    final channels = radioKey == null
        ? const <Channel>[]
        : ref.watch(channelsProvider(radioKey)).value ?? const <Channel>[];
    final joinedCodes = {for (final c in channels) channelCode(c.secret)};
    final joinedNames = {for (final c in channels) c.name.toLowerCase()};
    final heard = ref.watch(heardChannelsProvider);
    final local = localChannels(ref.watch(activeAreaProvider));
    final known = {...local, for (final g in channelDirectory) ...g.names};

    Widget tile(String name, {String? note}) {
      final code = hashtagCode(name);
      final joined = joinedNames.contains(name.toLowerCase());
      final h = heard[code];
      final subtitle = [
        ?note,
        if (h != null)
          'Probably heard on air: ${h.count}×, last ${_ago(h.last)}',
      ].join(' · ');
      return ListTile(
        leading: Icon(
          h != null ? Icons.wifi_tethering : Icons.tag,
          color: h != null ? theme.colorScheme.primary : null,
        ),
        title: Text(name),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: joined
            ? Chip(label: Text(context.l10n.joined))
            : FilledButton.tonal(
                onPressed: connected
                    ? () => joinHashtag(context, ref, name)
                    : null,
                child: Text(context.l10n.join, semanticsLabel: 'Join $name'),
              ),
      );
    }

    final typed = _search.text.trim();
    final searchName = typed.isEmpty ? null : hashtagName(typed);
    // Codes heard that aren't a joined channel.
    final unheardOf =
        heard.entries.where((e) => !joinedCodes.contains(e.key)).toList()
          ..sort((a, b) => b.value.count.compareTo(a.value.count));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.findChannels)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.anyHashtagChannel,
                hintText: context.l10n.hiking,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (searchName != null) tile(searchName),
          _Header(
            'Heard on air',
            connected
                ? 'Channels with traffic since you connected that you '
                      'haven’t joined.'
                : 'Connect a radio to hear which channels are in use.',
          ),
          if (connected && unheardOf.isEmpty)
            ListTile(
              dense: true,
              title: Text(context.l10n.nothingYetLeaveThisOpenA),
            ),
          for (final MapEntry(key: code, value: h) in unheardOf)
            if (namesForCode(code, known) case final names
                when names.isNotEmpty)
              for (final name in names) tile(name)
            else
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text('Unnamed channel (code ${codeLabel(code)})'),
                subtitle: Text(
                  'Heard ${h.count}×, last ${_ago(h.last)}. A private '
                  'channel, or a #name not listed here: ask around, then '
                  'type it above.',
                ),
              ),
          if (local.isNotEmpty) ...[
            const _Header('Near you', 'Named after your area.'),
            for (final name in local) tile(name),
          ],
          for (final group in channelDirectory) ...[
            _Header(group.title, null),
            for (final name in group.names) tile(name),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.note);

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (note case final note?)
          Text(note, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
