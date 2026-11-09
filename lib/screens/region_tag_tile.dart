import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/region_tag.dart';

/// Sets the short tag added to your channel posts.
class RegionTagTile extends ConsumerStatefulWidget {
  const RegionTagTile({super.key});

  @override
  ConsumerState<RegionTagTile> createState() => _RegionTagTileState();
}

class _RegionTagTileState extends ConsumerState<RegionTagTile> {
  String? _tag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(regionTagSetting);
    if (mounted) setState(() => _tag = cleanRegionTag(raw));
  }

  Future<void> _edit() async {
    final store = ref.read(storeProvider);
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _TagDialog(initial: _tag ?? ''),
    );
    if (picked == null || !mounted) return;
    final clean = cleanRegionTag(picked);
    if (clean == null) {
      await store.removeSetting(regionTagSetting);
    } else {
      await store.saveSetting(regionTagSetting, clean);
    }
    if (mounted) setState(() => _tag = clean);
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.place_outlined),
    title: const Text('Region tag on channel posts'),
    subtitle: Text(_tag == null ? 'Off' : 'Adds 📍 $_tag to your posts'),
    onTap: _edit,
  );
}

class _TagDialog extends StatefulWidget {
  const _TagDialog({required this.initial});

  final String initial;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Region tag'),
    content: TextField(
      controller: _text,
      maxLength: regionTagMaxLength,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Tag',
        hintText: 'ct',
        helperText: 'Leave empty to turn it off.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_text.text),
        child: const Text('Save'),
      ),
    ],
  );
}
