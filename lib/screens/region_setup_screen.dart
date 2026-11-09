import 'package:flutter/material.dart';

import '../app/repeater_regions.dart';
import '../radio/protocol/region_scope.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

enum _Tree {
  us('United States', 'usa', usRegions),
  canada('Canada', 'canada', canadaRegions),
  own('My own list', null, <String>[]);

  const _Tree(this.label, this.parent, this.regions);

  final String label;
  final String? parent;
  final List<String> regions;
}

/// Chooses regions for a repeater and sends the commands to set them up.
class RegionSetupScreen extends StatefulWidget {
  const RegionSetupScreen({required this.send, super.key});

  /// Sends one console command to the repeater.
  final Future<void> Function(String command) send;

  @override
  State<RegionSetupScreen> createState() => _RegionSetupScreenState();
}

class _RegionSetupScreenState extends State<RegionSetupScreen> {
  _Tree _tree = _Tree.us;
  final _picked = <String>{};
  final _own = TextEditingController();
  String? _home;
  bool _sending = false;
  int _sent = 0;

  /// Keeps a mesh's airtime clear between commands.
  static const _gap = Duration(seconds: 2);

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  List<String> get _regions => [..._picked, ...regionNames(_own.text)];

  List<String> get _commands =>
      regionSetupCommands(regions: _regions, parent: _tree.parent, home: _home);

  Future<void> _sendAll(List<String> commands) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _sending = true;
      _sent = 0;
    });
    try {
      for (final (i, command) in commands.indexed) {
        if (i > 0) await Future<void>.delayed(_gap);
        await widget.send(command);
        if (mounted) setState(() => _sent = i + 1);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sent. Check the console for the repeater’s replies.'),
        ),
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
    final commands = _commands;
    final regions = _regions.toSet().toList();
    final home = regions.contains(_home) ? _home : null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.regionSetup)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<_Tree>(
            initialValue: _tree,
            decoration: InputDecoration(labelText: context.l10n.regionsFrom),
            items: [
              for (final t in _Tree.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (t) => setState(() {
              _tree = t ?? _tree;
              _picked.clear();
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final r in _tree.regions)
                FilterChip(
                  label: Text(r.toUpperCase()),
                  selected: _picked.contains(r),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _picked.add(r);
                    } else {
                      _picked.remove(r);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _own,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.otherRegions,
              hintText: context.l10n.hudsonNyc,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(regions.join(',')),
            initialValue: home,
            decoration: InputDecoration(labelText: context.l10n.homeRegion),
            items: [
              for (final r in regions)
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (r) => setState(() => _home = r),
          ),
          const SizedBox(height: 16),
          if (commands.isNotEmpty) ...[
            Text(
              context.l10n.willSend,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final c in commands) Text(c),
            const SizedBox(height: 8),
            const Text(
              'This only adds regions and allows floods in them. A repeater '
              'holds a limited number, and it will say if it runs out.',
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: commands.isEmpty || _sending
                ? null
                : () => _sendAll(commands),
            child: Text(
              _sending
                  ? 'Sending $_sent of ${commands.length}…'
                  : 'Send to repeater',
            ),
          ),
        ],
      ),
    );
  }
}
