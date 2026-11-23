import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/channel_conflicts.dart';
import '../app/connection.dart';
import '../l10n/l10n.dart';
import '../data/mesh_sync.dart';

/// Above the chats when the radio's channels changed behind this device's
/// back. Opens a sheet to choose, slot by slot, which version stays.
class ChannelMismatchBanner extends ConsumerWidget {
  const ChannelMismatchBanner({required this.radioKey, super.key});

  final String radioKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list =
        ref.watch(channelMismatchesProvider(radioKey)).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    void open() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MismatchSheet(radioKey: radioKey),
    );
    return Card(
      key: const Key('channel-mismatch-banner'),
      color: scheme.errorContainer,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ListTile(
        leading: Icon(Icons.sync_problem, color: scheme.onErrorContainer),
        title: Text(
          context.l10n.channelMismatchBanner(list.length),
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        trailing: TextButton(
          onPressed: open,
          child: Text(context.l10n.channelMismatchReview),
        ),
        onTap: open,
      ),
    );
  }
}

class _MismatchSheet extends ConsumerStatefulWidget {
  const _MismatchSheet({required this.radioKey});

  final String radioKey;

  @override
  ConsumerState<_MismatchSheet> createState() => _MismatchSheetState();
}

class _MismatchSheetState extends ConsumerState<_MismatchSheet> {
  int? _busySlot;

  Future<void> _act(int slot, Future<void> Function(MeshSync sync) act) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(connectionProvider);
    if (state is! Connected) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.connectToTheRadioFirst)),
      );
      return;
    }
    setState(() => _busySlot = slot);
    try {
      await act(state.sync);
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.radioCouldNotSendRequest)),
      );
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  String _describe(SlotState? s) {
    final l10n = context.l10n;
    if (s == null) return l10n.channelMismatchEmpty;
    return '${s.name.isEmpty ? '—' : s.name} · '
        '${l10n.channelMismatchKeyTag(secretTag(s.secret))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final list =
        ref.watch(channelMismatchesProvider(widget.radioKey)).value ?? const [];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(l10n.channelMismatchTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.channelMismatchExplain),
            const SizedBox(height: 12),
            if (list.isEmpty) Text(l10n.channelMismatchNone),
            for (final m in list)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.channelMismatchSlot(m.mine.slot),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.channelMismatchRadioSide}: '
                        '${_describe(m.radio)}',
                      ),
                      Text(
                        '${l10n.channelMismatchDeviceSide}: '
                        '${_describe(m.mine)}',
                      ),
                      const SizedBox(height: 8),
                      if (_busySlot == m.mine.slot)
                        const LinearProgressIndicator(),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            key: Key('keep-radio-${m.mine.slot}'),
                            onPressed: _busySlot != null
                                ? null
                                : () => _act(
                                    m.mine.slot,
                                    (s) => s.keepRadioChannel(m.mine.slot),
                                  ),
                            child: Text(l10n.channelMismatchKeepRadio),
                          ),
                          FilledButton(
                            key: Key('restore-${m.mine.slot}'),
                            onPressed: _busySlot != null
                                ? null
                                : () => _act(
                                    m.mine.slot,
                                    (s) => s.restoreSavedChannel(m.mine.slot),
                                  ),
                            child: Text(l10n.channelMismatchRestore),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
