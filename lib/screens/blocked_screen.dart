import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/blocking.dart';
import '../app/connection.dart';
import '../data/data.dart';

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
      appBar: AppBar(title: const Text('Blocked senders')),
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
                  const ListTile(title: Text('On channels, by name')),
                for (final name in names)
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text(name),
                    trailing: TextButton(
                      onPressed: () => blocking.unblockName(name),
                      child: Text('Unblock', semanticsLabel: 'Unblock $name'),
                    ),
                  ),
                if (keys.isNotEmpty)
                  const ListTile(title: Text('Direct messages')),
                for (final key in keys)
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined),
                    title: Text(nameOf(key)),
                    trailing: TextButton(
                      onPressed: () => blocking.unblockKey(key),
                      child: Text(
                        'Unblock',
                        semanticsLabel: 'Unblock ${nameOf(key)}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
