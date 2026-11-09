import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/blocking.dart';
import '../app/connection.dart';
import '../app/spam_filter.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';

/// Turns the channel repeat filter on or off.
class SpamFilterTile extends ConsumerWidget {
  const SpamFilterTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SwitchListTile(
    secondary: const Icon(Icons.filter_alt_outlined),
    title: Text(context.l10n.hideRepeatedChannelPosts),
    subtitle: const Text(
      'After someone posts the same thing twice in 30 minutes, hides the '
      'rest. SOS posts and mentions of you always show.',
    ),
    value: ref.watch(spamFilterProvider).value ?? false,
    onChanged: (on) => setSpamFilter(ref.read(storeProvider), on: on),
  );
}

/// Everyone blocked, with a way to unblock them.
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockListProvider).value ?? const BlockList();
    final radioKey = ref.watch(radioKeyProvider);
    final contacts = radioKey == null
        ? const <Contact>[]
        : ref.watch(contactsProvider(radioKey)).value ?? const <Contact>[];
    String nameOf(String key) =>
        contacts.where((c) => c.publicKey == key).firstOrNull?.name ??
        'Unknown ${key.substring(0, 8)}';
    final blocking = ref.read(blockingProvider);
    final names = blocked.names.toList()..sort();
    final keys = blocked.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.blockedSenders)),
      body: blocked.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nobody is blocked. To block someone, hold one of their '
                  'messages.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Their messages are kept but hidden, and don’t notify. '
                    'Unblocking brings them back.',
                  ),
                ),
                if (names.isNotEmpty)
                  ListTile(title: Text(context.l10n.onChannelsByName)),
                for (final name in names)
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text(name),
                    trailing: TextButton(
                      onPressed: () => blocking.unblockName(name),
                      child: Text(
                        context.l10n.unblock,
                        semanticsLabel: 'Unblock $name',
                      ),
                    ),
                  ),
                if (keys.isNotEmpty)
                  ListTile(title: Text(context.l10n.directMessages)),
                for (final key in keys)
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined),
                    title: Text(nameOf(key)),
                    trailing: TextButton(
                      onPressed: () => blocking.unblockKey(key),
                      child: Text(
                        context.l10n.unblock,
                        semanticsLabel: 'Unblock ${nameOf(key)}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
