import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'connection_log_screen.dart';
import 'area_screen.dart';
import 'conversation_screen.dart';
import 'manage_actions.dart';

/// A radio's chats and contacts. While the radio is being reconnected a
/// banner says so and the stored chats stay readable.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    required this.radioKey,
    required this.radioName,
    super.key,
  });

  final String radioKey;
  final String radioName;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  /// Unread messages outside muted threads.
  int _unreadTotal() {
    final unread =
        ref.watch(unreadCountsProvider(widget.radioKey)).value ?? const {};
    final muted =
        ref.watch(mutedThreadsProvider(widget.radioKey)).value ?? const {};
    return unread.entries
        .where((e) => !muted.contains(e.key))
        .fold(0, (sum, e) => sum + e.value);
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.radioKey;
    final connection = ref.watch(connectionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.radioName),
        actions: [
          const ConnectionLogButton(),
          IconButton(
            tooltip: 'Local mesh settings',
            icon: const Icon(Icons.public),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AreaScreen())),
          ),
          IconButton(
            tooltip: 'Disconnect',
            icon: const Icon(Icons.link_off),
            onPressed: () => ref.read(connectionProvider.notifier).disconnect(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (connection case Reconnecting(:final attempt, :final error))
            _ReconnectBanner(attempt: attempt, error: error),
          const AreaBanner(),
          Expanded(
            child: switch (_tab) {
              0 => _ChatsTab(radioKey: key),
              _ => _ContactsTab(radioKey: key),
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: _tab == 0 ? 'Add a channel' : 'Add or share contacts',
        onPressed: () => _tab == 0
            ? showAddChannel(context, ref)
            : showContactsMenu(
                context,
                ref,
                radioName: widget.radioName,
                radioKey: widget.radioKey,
              ),
        child: Icon(
          _tab == 0 ? Icons.add_comment_outlined : Icons.person_add_alt,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: _UnreadBadge(
              count: _unreadTotal(),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: _UnreadBadge(
              count: _unreadTotal(),
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Chats',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
        ],
      ),
    );
  }
}

void _openThread(
  BuildContext context, {
  required String thread,
  required String title,
  bool isChannel = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ConversationScreen(
        thread: thread,
        title: title,
        isChannel: isChannel,
      ),
    ),
  );
}

/// Channels first, then direct conversations, each with its newest message.
class _ChatsTab extends ConsumerWidget {
  const _ChatsTab({required this.radioKey});

  final String radioKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider(radioKey)).value ?? const [];
    final latest = ref.watch(conversationsProvider(radioKey)).value ?? const [];
    final contacts = ref.watch(contactsProvider(radioKey)).value ?? const [];
    final byThread = {for (final m in latest) m.thread: m};
    final names = {for (final c in contacts) c.publicKey: c.name};
    final unread = ref.watch(unreadCountsProvider(radioKey)).value ?? const {};
    final muted = ref.watch(mutedThreadsProvider(radioKey)).value ?? const {};
    final direct = latest.where((m) => m.kind == MessageKind.direct).toList();

    if (channels.isEmpty && direct.isEmpty) {
      return const _Empty('No chats yet');
    }
    return ListView(
      children: [
        for (final channel in channels)
          _ThreadTile(
            icon: Icons.tag,
            title: channel.name,
            latest: byThread[Threads.channel(channel.slot)],
            unread: unread[Threads.channel(channel.slot)] ?? 0,
            muted: muted.contains(Threads.channel(channel.slot)),
            onLongPress: () => showChannelActions(
              context,
              ref,
              radioKey: radioKey,
              channel: channel,
            ),
            onTap: () => _openThread(
              context,
              thread: Threads.channel(channel.slot),
              title: channel.name,
              isChannel: true,
            ),
          ),
        if (channels.isNotEmpty && direct.isNotEmpty) const Divider(),
        for (final message in direct)
          _ThreadTile(
            icon: Icons.person_outline,
            title: _directTitle(message.thread, names),
            latest: message,
            unread: unread[message.thread] ?? 0,
            muted: muted.contains(message.thread),
            onLongPress: () => _toggleMute(context, ref, message.thread),
            onTap: () => _openThread(
              context,
              thread: message.thread,
              title: _directTitle(message.thread, names),
            ),
          ),
      ],
    );
  }

  Future<void> _toggleMute(
    BuildContext context,
    WidgetRef ref,
    String thread,
  ) async {
    final store = ref.read(storeProvider);
    final muted = await store.isMuted(radioKey, thread);
    if (!context.mounted) return;
    final change = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: Icon(
            muted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
          ),
          title: Text(muted ? 'Unmute' : 'Mute notifications'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (change == true) await store.setMuted(radioKey, thread, !muted);
  }

  static String _directTitle(String thread, Map<String, String> names) {
    final key = thread.substring(2);
    return names[key] ?? 'Unknown ${key.substring(0, 6)}';
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.icon,
    required this.title,
    required this.latest,
    required this.onTap,
    this.unread = 0,
    this.muted = false,
    this.onLongPress,
  });

  final IconData icon;
  final String title;
  final Message? latest;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int unread;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final message = latest;
    final preview = message == null
        ? null
        : [
            if (message.outgoing) 'You' else ?message.senderName,
            message.body,
          ].join(': ');
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(
        title,
        style: unread > 0 ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: preview == null
          ? null
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (muted)
            Icon(
              Icons.notifications_off_outlined,
              size: 18,
              semanticLabel: 'Muted',
              color: scheme.onSurfaceVariant,
            ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Badge(
              label: Text(unread > 99 ? '99+' : '$unread'),
              backgroundColor: muted ? scheme.outline : null,
            ),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab({required this.radioKey});

  final String radioKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider(radioKey)).value ?? const [];
    final heard = ref.watch(discoveredProvider(radioKey)).value ?? const [];
    if (contacts.isEmpty && heard.isEmpty) {
      return const _Empty('No contacts on this radio');
    }
    // Favourites first, each group by name (the store already sorts by name).
    final sorted = [
      ...contacts.where((c) => c.flags & 1 == 1),
      ...contacts.where((c) => c.flags & 1 == 0),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // room for the + button
      children: [
        for (final contact in sorted)
          ListTile(
            leading: CircleAvatar(child: Icon(_icon(contact.type))),
            title: Text(contact.name),
            subtitle: Text(_describe(contact)),
            trailing: contact.flags & 1 == 1
                ? const Icon(Icons.star, semanticLabel: 'Favourite')
                : null,
            onTap: NodeType.fromByte(contact.type) == NodeType.chat
                ? () => _openThread(
                    context,
                    thread: Threads.direct(contact.publicKey),
                    title: contact.name,
                  )
                : null,
            onLongPress: () =>
                showContactActions(context, ref, contact: contact),
          ),
        if (heard.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              'Heard nearby, not added',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final node in heard)
            ListTile(
              leading: CircleAvatar(child: Icon(_icon(node.type))),
              title: Text(node.name),
              subtitle: Text(_kind(node.type)),
              trailing: TextButton(
                onPressed: () => addDiscovered(context, ref, node),
                child: const Text('Add'),
              ),
            ),
        ],
      ],
    );
  }

  static IconData _icon(int type) => switch (NodeType.fromByte(type)) {
    NodeType.repeater => Icons.cell_tower,
    NodeType.room => Icons.forum_outlined,
    NodeType.sensor => Icons.sensors,
    _ => Icons.person_outline,
  };

  static String _kind(int type) => switch (NodeType.fromByte(type)) {
    NodeType.repeater => 'Repeater',
    NodeType.room => 'Room',
    NodeType.sensor => 'Sensor',
    _ => 'Person',
  };

  static String _describe(Contact c) {
    final kind = _kind(c.type);
    if (c.outPathLength == pathUnknown) return '$kind · no route yet';
    final hops = c.outPathLength & 0x3F;
    return '$kind · ${hops == 0 ? 'direct' : '$hops hops'}';
  }
}

class _ReconnectBanner extends ConsumerWidget {
  const _ReconnectBanner({required this.attempt, this.error});

  final int attempt;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attempt == 0
                        ? 'Reconnecting to the radio\u2026'
                        : 'Reconnecting to the radio (try ${attempt + 1})\u2026',
                  ),
                  if (error case final error?)
                    Text(error, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ref.read(connectionProvider.notifier).retryNow(),
              child: const Text('Try now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => count == 0
      ? child
      : Badge(label: Text(count > 99 ? '99+' : '$count'), child: child);
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
  );
}
