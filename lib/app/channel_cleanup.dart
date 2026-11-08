/// Removing old channel messages, if the person turns it on.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';

const channelKeepDaysSetting = 'channel_keep_days';

/// Days to keep channel messages; 0 keeps them for ever.
final channelKeepDaysProvider = NotifierProvider<ChannelKeepDays, int>(
  ChannelKeepDays.new,
);

class ChannelKeepDays extends Notifier<int> {
  @override
  int build() {
    unawaited(_load());
    return 0;
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(channelKeepDaysSetting);
    if (ref.mounted) state = int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> set(int days) async {
    state = days;
    final store = ref.read(storeProvider);
    await store.saveSetting(channelKeepDaysSetting, '$days');
    if (days > 0) await store.deleteOldChannelMessages(Duration(days: days));
  }
}

/// Cleans up at launch and every six hours while the app runs.
final channelCleanerProvider = Provider<void>((ref) {
  Future<void> clean() async {
    final store = ref.read(storeProvider);
    final days = int.tryParse(
      await store.setting(channelKeepDaysSetting) ?? '',
    );
    if (days != null && days > 0) {
      await store.deleteOldChannelMessages(Duration(days: days));
    }
  }

  void run() => unawaited(
    clean().catchError((Object e) {
      ref.read(connectionLogProvider).add('cleanup: $e');
    }),
  );

  run();
  final timer = Timer.periodic(const Duration(hours: 6), (_) => run());
  ref.onDispose(timer.cancel);
});

/// The setting's row in Radio settings.
class ChannelCleanupTile extends ConsumerWidget {
  const ChannelCleanupTile({super.key});

  static String _label(int days) => days == 0 ? 'Forever' : '$days days';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(channelKeepDaysProvider);
    return ListTile(
      leading: const Icon(Icons.auto_delete_outlined),
      title: const Text('Keep channel messages'),
      subtitle: Text(_label(days)),
      onTap: () async {
        final picked = await showDialog<int>(
          context: context,
          builder: (dialog) => SimpleDialog(
            title: const Text('Keep channel messages'),
            children: [
              for (final d in const [0, 7, 30, 90])
                SimpleDialogOption(
                  onPressed: () => Navigator.of(dialog).pop(d),
                  child: Text(_label(d)),
                ),
            ],
          ),
        );
        if (picked != null) {
          await ref.read(channelKeepDaysProvider.notifier).set(picked);
        }
      },
    );
  }
}
