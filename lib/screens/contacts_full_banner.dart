import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../l10n/l10n.dart';

/// Warns that the radio's contact list is full, so new nodes it hears
/// won't be added until some contacts are removed.
class ContactsFullBanner extends ConsumerWidget {
  const ContactsFullBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionProvider);
    if (state is! Connected) return const SizedBox.shrink();
    final sync = state.sync;
    return StreamBuilder<bool>(
      stream: sync.contactsFullChanges,
      initialData: sync.contactsFull,
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(Icons.group_off_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.contactsFullWarning,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
