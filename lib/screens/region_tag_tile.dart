import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/region_tag.dart';
import '../radio/protocol/region_scope.dart';

/// Chooses the region channel posts go out in, and which regions to show.
class RegionTagTile extends ConsumerStatefulWidget {
  const RegionTagTile({super.key});

  @override
  ConsumerState<RegionTagTile> createState() => _RegionTagTileState();
}

class _RegionTagTileState extends ConsumerState<RegionTagTile> {
  String? _send;
  String _known = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final store = ref.read(storeProvider);
    final send = await store.setting(regionSendSetting);
    final known = await store.setting(regionKnownSetting);
    if (!mounted) return;
    setState(() {
      _send = cleanRegionName(send);
      _known = regionNames(known).join(', ');
    });
  }

  Future<void> _edit() async {
    final store = ref.read(storeProvider);
    final picked = await showDialog<({String send, String known})>(
      context: context,
      builder: (_) => _RegionDialog(send: _send ?? '', known: _known),
    );
    if (picked == null || !mounted) return;
    final send = cleanRegionName(picked.send);
    final known = regionNames(picked.known).join(', ');
    if (send == null) {
      await store.removeSetting(regionSendSetting);
    } else {
      await store.saveSetting(regionSendSetting, send);
    }
    await store.saveSetting(regionKnownSetting, known);
    if (mounted) {
      setState(() {
        _send = send;
        _known = known;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.place_outlined),
    title: const Text('Channel post region'),
    subtitle: Text(_send == null ? 'Off' : 'Posts go out in $_send'),
    onTap: _edit,
  );
}

class _RegionDialog extends StatefulWidget {
  const _RegionDialog({required this.send, required this.known});

  final String send;
  final String known;

  @override
  State<_RegionDialog> createState() => _RegionDialogState();
}

class _RegionDialogState extends State<_RegionDialog> {
  late final _send = TextEditingController(text: widget.send);
  late final _known = TextEditingController(text: widget.known);

  @override
  void dispose() {
    _send.dispose();
    _known.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Channel post region'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Only repeaters that allow this region pass your post on. If '
            'yours don\'t, your posts won\'t get past your own radio\'s '
            'range. SOS and check-ins never use a region.',
          ),
          TextField(
            controller: _send,
            decoration: const InputDecoration(
              labelText: 'Send my posts in',
              hintText: 'ct',
              helperText: 'Leave empty for no region.',
            ),
          ),
          TextField(
            controller: _known,
            decoration: const InputDecoration(
              labelText: 'Also show these regions',
              hintText: 'ny, ma',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () =>
            Navigator.of(context).pop((send: _send.text, known: _known.text)),
        child: const Text('Save'),
      ),
    ],
  );
}
