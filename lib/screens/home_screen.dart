import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'conversation_screen.dart';

/// The connected radio's chats and contacts.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.radio, super.key});

  final ConnectedRadio radio;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final key = widget.radio.key;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.radio.self.name),
        actions: [
          IconButton(
            tooltip: 'Disconnect',
            icon: const Icon(Icons.link_off),
            onPressed: () => ref.read(connectionProvider.notifier).disconnect(),
          ),
        ],
      ),
      body: switch (_tab) {
        0 => _ChatsTab(radioKey: key),
        _ => _ContactsTab(radioKey: key),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
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
            onTap: () => _openThread(
              context,
              thread: message.thread,
              title: _directTitle(message.thread, names),
            ),
          ),
      ],
    );
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
  });

  final IconData icon;
  final String title;
  final Message? latest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final message = latest;
    final preview = message == null
        ? null
        : [
            if (message.outgoing) 'You' else ?message.senderName,
            message.body,
          ].join(': ');
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: preview == null
          ? null
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab({required this.radioKey});

  final String radioKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider(radioKey)).value ?? const [];
    if (contacts.isEmpty) return const _Empty('No contacts on this radio');
    return ListView(
      children: [
        for (final contact in contacts)
          ListTile(
            leading: CircleAvatar(child: Icon(_icon(contact.type))),
            title: Text(contact.name),
            subtitle: Text(_describe(contact)),
            onTap: NodeType.fromByte(contact.type) == NodeType.chat
                ? () => _openThread(
                    context,
                    thread: Threads.direct(contact.publicKey),
                    title: contact.name,
                  )
                : null,
          ),
      ],
    );
  }

  static IconData _icon(int type) => switch (NodeType.fromByte(type)) {
    NodeType.repeater => Icons.cell_tower,
    NodeType.room => Icons.forum_outlined,
    NodeType.sensor => Icons.sensors,
    _ => Icons.person_outline,
  };

  static String _describe(Contact c) {
    final kind = switch (NodeType.fromByte(c.type)) {
      NodeType.repeater => 'Repeater',
      NodeType.room => 'Room',
      NodeType.sensor => 'Sensor',
      _ => 'Person',
    };
    if (c.outPathLength == pathUnknown) return '$kind · no route yet';
    final hops = c.outPathLength & 0x3F;
    return '$kind · ${hops == 0 ? 'direct' : '$hops hops'}';
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
  );
}
