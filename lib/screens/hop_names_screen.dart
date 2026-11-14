import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/hop_names.dart';
import '../l10n/l10n.dart';

/// How repeater IDs in paths get names: online lookup for unknown IDs, and
/// the memory for IDs several known repeaters share.
class HopNamesScreen extends ConsumerStatefulWidget {
  const HopNamesScreen({super.key});

  @override
  ConsumerState<HopNamesScreen> createState() => _HopNamesScreenState();
}

class _HopNamesScreenState extends ConsumerState<HopNamesScreen> {
  late final _server = TextEditingController(
    text: ref.read(hopNamesProvider).server,
  );

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = ref.watch(hopNamesProvider);
    final notifier = ref.read(hopNamesProvider.notifier);
    final picks = names.tieCount(DateTime.now());
    final small = Theme.of(context).textTheme.bodySmall;
    Widget stepper({
      required Key key,
      required IconData icon,
      required String title,
      required String value,
      required VoidCallback? less,
      required VoidCallback? more,
    }) => ListTile(
      key: key,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.less,
            onPressed: less,
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            tooltip: l.more,
            onPressed: more,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.repeaterNames)),
      body: ListView(
        children: [
          SwitchListTile(
            key: const ValueKey('hop-online'),
            title: Text(l.lookUpUnknownIdsOnline),
            subtitle: Text(l.lookUpUnknownIdsOnlineDetail),
            value: names.online,
            onChanged: notifier.setOnline,
          ),
          if (names.online)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('hop-server'),
                controller: _server,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(labelText: l.lookupServer),
                onSubmitted: notifier.setServer,
              ),
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.sharedIdMemoryExplainer, style: small),
          ),
          stepper(
            key: const ValueKey('hop-days'),
            icon: Icons.history,
            title: l.rememberPicksFor,
            value: l.daysShort(names.tieDays),
            less: names.tieDays > 1
                ? () => notifier.setTieDays(names.tieDays - 1)
                : null,
            more: names.tieDays < maxTieDays
                ? () => notifier.setTieDays(names.tieDays + 1)
                : null,
          ),
          stepper(
            key: const ValueKey('hop-margin'),
            icon: Icons.balance,
            title: l.tieMargin,
            value: '${names.tieMargin} %',
            less: names.tieMargin > 0
                ? () => notifier.setTieMargin(names.tieMargin - 1)
                : null,
            more: names.tieMargin < maxTieMargin
                ? () => notifier.setTieMargin(names.tieMargin + 1)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.tieMarginDetail, style: small),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              key: const ValueKey('hop-forget'),
              onPressed: picks == 0 ? null : notifier.forgetPicks,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(l.forgetPicks(picks)),
            ),
          ),
        ],
      ),
    );
  }
}
