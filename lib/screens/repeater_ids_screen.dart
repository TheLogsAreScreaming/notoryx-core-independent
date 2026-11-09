import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/repeater_regions.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

/// Which 1-byte repeater IDs are in use around here, and which are free.
class RepeaterIdsScreen extends ConsumerStatefulWidget {
  const RepeaterIdsScreen({super.key});

  @override
  ConsumerState<RepeaterIdsScreen> createState() => _RepeaterIdsScreenState();
}

class _RepeaterIdsScreenState extends ConsumerState<RepeaterIdsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(radioKeyProvider) ?? '';
    final repeater = NodeType.repeater.value;
    final used = repeaterIdUsage([
      for (final c in ref.watch(contactsProvider(key)).value ?? const [])
        if (c.type == repeater) (name: c.name, publicKey: c.publicKey),
      for (final d in ref.watch(discoveredProvider(key)).value ?? const [])
        if (d.type == repeater) (name: d.name, publicKey: d.publicKey),
    ]);
    final free = freeRepeaterIds(used);
    final query = _query.trim().toUpperCase();
    final lookup = query.length == 2 ? int.tryParse(query, radix: 16) : null;
    final ids = used.keys.toList()..sort();
    final shown = [
      for (final id in ids)
        if (query.isEmpty || idLabel(id).startsWith(query)) id,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.repeaterIDs)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.l10n.aRepeaterSIDIsThe),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: context.l10n.lookUpAnID,
              hintText: context.l10n.a7,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          if (lookup != null && !used.containsKey(lookup))
            Text(context.l10n.isFree(query)),
          for (final id in shown)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(
                idLabel(id),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              title: Text([for (final n in used[id]!) n.name].join(', ')),
              subtitle: used[id]!.length > 1
                  ? Text(context.l10n.repeatersShareThisID(used[id]!.length))
                  : null,
            ),
          const Divider(height: 32),
          Text(
            context.l10n.free(free.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text([for (final id in free) idLabel(id)].join(' ')),
        ],
      ),
    );
  }
}
