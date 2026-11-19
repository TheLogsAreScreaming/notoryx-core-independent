import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../app/favourites_view.dart';
import '../app/connection.dart';
import '../app/contact_room.dart';
import '../app/quick_messages.dart';
import '../app/stale_nodes.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'connect_screen.dart';
import 'connection_log_screen.dart';
import 'contact_cleanup_screen.dart';
import 'area_screen.dart';
import '../l10n/l10n.dart';
import 'battery_banner.dart';
import 'own_status_strip.dart';
import 'conversation_screen.dart';
import 'manage_actions.dart';
import 'map_tab.dart';
import 'background_layer.dart';
import 'node_avatar.dart';
import 'node_details.dart';
import 'radio_settings_screen.dart';
import 'search_screen.dart';
import 'server_screen.dart';
import 'safety_screen.dart';
import 'scheduled_screen.dart';

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

  @override
  void initState() {
    super.initState();
  }

  bool _shortcutsSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Titles need the app's language, which isn't known until now.
    if (!_shortcutsSet && Platform.isAndroid) {
      _shortcutsSet = true;
      _setUpShortcuts();
    }
  }

  /// Long-press shortcuts on the app icon. Safety only opens the screen:
  /// sending an SOS always takes the deliberate hold there.
  void _setUpShortcuts() {
    const actions = QuickActions();
    actions.initialize((type) {
      if (!mounted) return;
      switch (type) {
        case 'safety':
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SafetyScreen()));
        case 'map':
          setState(() => _tab = 2);
        case 'search':
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SearchScreen(radioKey: widget.radioKey),
            ),
          );
      }
    });
    actions
        .setShortcutItems([
          ShortcutItem(
            type: 'safety',
            localizedTitle: context.l10n.shortcutSafety,
          ),
          ShortcutItem(type: 'map', localizedTitle: context.l10n.shortcutMap),
          ShortcutItem(
            type: 'search',
            localizedTitle: context.l10n.shortcutSearch,
          ),
        ])
        .catchError((Object e) {
          ref.read(connectionLogProvider).add('app shortcuts: $e');
        });
  }

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
          IconButton(
            tooltip: context.l10n.searchMessages,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchScreen(radioKey: widget.radioKey),
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.safetyTooltip,
            icon: const Icon(Icons.health_and_safety_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SafetyScreen()),
            ),
          ),
          const ConnectionLogButton(),
          IconButton(
            tooltip: context.l10n.localMeshSettings,
            icon: const Icon(Icons.public),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AreaScreen())),
          ),
          IconButton(
            tooltip: context.l10n.radioSettings,
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RadioSettingsScreen(),
              ),
            ),
          ),
          if (connection is ViewingSaved)
            IconButton(
              tooltip: context.l10n.connectARadio,
              icon: const Icon(Icons.link),
              onPressed: () => _openConnect(context),
            )
          else
            IconButton(
              tooltip: context.l10n.disconnect,
              icon: const Icon(Icons.link_off),
              onPressed: () =>
                  ref.read(connectionProvider.notifier).disconnect(),
            ),
        ],
      ),
      body: Column(
        children: [
          const SosBanner(),
          if (connection case Reconnecting(:final attempt, :final error))
            _ReconnectBanner(attempt: attempt, error: error),
          if (connection is ViewingSaved) const _ViewingSavedBanner(),
          const BatteryBanner(),
          const AreaBanner(),
          if (_tab == 0)
            OwnStatusStrip(radioKey: key, radioName: widget.radioName),
          if (_tab == 0) const ScheduledStrip(),
          Expanded(
            child: switch (_tab) {
              0 => _ChatsTab(radioKey: key),
              1 => _ContactsTab(radioKey: key),
              _ => MapTab(radioKey: key),
            },
          ),
        ],
      ),
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton(
              tooltip: _tab == 0
                  ? context.l10n.addAChannel
                  : context.l10n.addOrShareContacts,
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
            label: context.l10n.navChats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: context.l10n.navContacts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: context.l10n.navMap,
          ),
        ],
      ),
    );
  }
}

/// Repeaters and rooms open their own screen; anything else shows details.
void _openNode(BuildContext context, WidgetRef ref, NodeSummary node) {
  if (node.type == NodeType.repeater || node.type == NodeType.room) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ServerScreen(node: node)));
  } else {
    showNodeDetails(context, ref, node);
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
    final drafts = ref.watch(draftsProvider(radioKey)).value ?? const {};
    final direct = latest.where((m) => m.kind == MessageKind.direct).toList();

    if (channels.isEmpty && direct.isEmpty) {
      return _Empty(context.l10n.noChatsYet);
    }
    return ListView(
      children: [
        for (final channel in channels)
          _ThreadTile(
            icon: Icons.tag,
            title: channel.name,
            latest: byThread[Threads.channel(channel.slot)],
            unread: unread[Threads.channel(channel.slot)] ?? 0,
            draft: drafts[Threads.channel(channel.slot)],
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
            avatar: NodeAvatar(
              publicKey: message.thread.substring(2),
              name: _directTitle(context.l10n, message.thread, names),
              type: NodeType.chat,
            ),
            title: _directTitle(context.l10n, message.thread, names),
            latest: message,
            unread: unread[message.thread] ?? 0,
            draft: drafts[message.thread],
            muted: muted.contains(message.thread),
            onLongPress: () => _toggleMute(context, ref, message.thread),
            onTap: () => _openThread(
              context,
              thread: message.thread,
              title: _directTitle(context.l10n, message.thread, names),
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
          title: Text(
            muted ? context.l10n.unmuteChat : context.l10n.muteNotifications,
          ),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (change == true) await store.setMuted(radioKey, thread, !muted);
  }

  static String _directTitle(
    AppLocalizations l10n,
    String thread,
    Map<String, String> names,
  ) {
    final key = thread.substring(2);
    return names[key] ?? l10n.unknownThread(key.substring(0, 6));
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
    this.draft,
    this.onLongPress,
    this.avatar,
  });

  /// Unsent text left in this chat, shown instead of the last message.
  final String? draft;

  /// Shown in place of [icon], such as a contact's picked look.
  final Widget? avatar;

  final IconData icon;
  final String title;
  final Message? latest;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int unread;
  final bool muted;

  @override
  Widget build(BuildContext context) => GlassCard(child: _tile(context));

  Widget _tile(BuildContext context) {
    final message = latest;
    final preview = message == null
        ? null
        : [
            if (message.outgoing)
              context.l10n.youLabel
            else
              ?message.senderName,
            message.body,
          ].join(': ');
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: avatar ?? CircleAvatar(child: Icon(icon)),
      title: Text(
        title,
        style: unread > 0 ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: draft != null
          ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: context.l10n.draftPrefix,
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: draft),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : preview == null
          ? null
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (muted)
            Icon(
              Icons.notifications_off_outlined,
              size: 18,
              semanticLabel: context.l10n.muted,
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
    final favouritesOnly = ref.watch(favouritesOnlyProvider).value ?? false;
    final heard = favouritesOnly
        ? const <DiscoveredData>[]
        : ref.watch(discoveredProvider(radioKey)).value ?? const [];
    if (contacts.isEmpty && heard.isEmpty) {
      return _Empty(context.l10n.noContactsOnRadio);
    }
    // Favourites first, each group by name (the store already sorts by name).
    final sorted = [
      ...contacts.where(isFavourite),
      if (!favouritesOnly) ...contacts.where((c) => !isFavourite(c)),
    ];
    final state = ref.watch(connectionProvider);
    final max = state is Connected ? state.radio.device.maxContacts : null;
    final staleAfter =
        (ref.watch(staleAfterProvider).value ?? StaleAfter.fallback).after;
    final now = DateTime.now();
    Widget subtitle(String text, int lastAdvert) =>
        isStale(advertTime(lastAdvert), now, staleAfter)
        ? _StaleSubtitle(text: text, lastAdvert: lastAdvert, now: now)
        : Text(text);
    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // room for the + button
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(
              key: const Key('favourites-only'),
              avatar: Icon(favouritesOnly ? Icons.star : Icons.star_outline),
              showCheckmark: false,
              label: Text(context.l10n.favouritesOnly),
              selected: favouritesOnly,
              onSelected: (on) =>
                  setFavouritesOnly(ref.read(storeProvider), on),
            ),
          ),
        ),
        if (favouritesOnly && sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.noFavouritesYet,
              textAlign: TextAlign.center,
            ),
          ),
        if (max != null && max > 0)
          ContactMeterBar(
            meter: ContactMeter(contacts.length, max),
            onMakeRoom: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ContactCleanupScreen(radioKey: radioKey),
              ),
            ),
          ),
        for (final contact in sorted)
          GlassCard(
            child: ListTile(
              leading: NodeAvatar(
                publicKey: contact.publicKey,
                name: contact.name,
                type: NodeType.fromByte(contact.type),
                icon: _icon(contact.type),
              ),
              title: Text(contact.name),
              subtitle: subtitle(
                _describe(context.l10n, contact),
                contact.lastAdvert,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (contact.flags & 1 == 1)
                    Icon(Icons.star, semanticLabel: context.l10n.favourite),
                  IconButton(
                    tooltip: context.l10n.detailsFor(contact.name),
                    icon: const Icon(Icons.info_outline),
                    onPressed: () =>
                        showNodeDetails(context, ref, nodeFromContact(contact)),
                  ),
                ],
              ),
              onTap: NodeType.fromByte(contact.type) == NodeType.chat
                  ? () => _openThread(
                      context,
                      thread: Threads.direct(contact.publicKey),
                      title: contact.name,
                    )
                  : () => _openNode(context, ref, nodeFromContact(contact)),
              onLongPress: () =>
                  showContactActions(context, ref, contact: contact),
            ),
          ),
        if (heard.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.heardNearbyNotAdded,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (heard.length > 1 && max != null && max > contacts.length)
                  TextButton(
                    onPressed: () => addSeveralDiscovered(
                      context,
                      ref,
                      heard,
                      max - contacts.length,
                    ),
                    child: Text(context.l10n.addSeveral),
                  ),
              ],
            ),
          ),
          for (final node in heard)
            GlassCard(
              child: ListTile(
                leading: NodeAvatar(
                  publicKey: node.publicKey,
                  name: node.name,
                  type: NodeType.fromByte(node.type),
                  icon: _icon(node.type),
                ),
                title: Text(node.name),
                subtitle: subtitle(
                  _kind(context.l10n, node.type),
                  node.lastAdvert,
                ),
                trailing: TextButton(
                  onPressed: () => addDiscovered(context, ref, node),
                  child: Text(context.l10n.add),
                ),
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

  static String _kind(AppLocalizations l10n, int type) =>
      switch (NodeType.fromByte(type)) {
        NodeType.repeater => l10n.kindRepeater,
        NodeType.room => l10n.kindRoom,
        NodeType.sensor => l10n.kindSensor,
        _ => l10n.kindPerson,
      };

  static String _describe(AppLocalizations l10n, Contact c) {
    final kind = _kind(l10n, c.type);
    if (c.outPathLength == pathUnknown) return l10n.kindNoRouteYet(kind);
    return l10n.kindWithHops(kind, c.outPathLength & 0x3F);
  }
}

/// A list row's subtitle with "stale · 3 days ago" under it, marked with an
/// icon as well as words so it doesn't rely on colour.
class _StaleSubtitle extends StatelessWidget {
  const _StaleSubtitle({
    required this.text,
    required this.lastAdvert,
    required this.now,
  });

  final String text;
  final int lastAdvert;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text),
        Row(
          children: [
            Icon(Icons.history_toggle_off, size: 16, color: style?.color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                context.l10n.staleBadge(timeAgo(lastAdvert, now, context.l10n)),
                style: style,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Says no radio is attached, and leads back to connecting one.
void _openConnect(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ConnectScreen()));

class _ViewingSavedBanner extends ConsumerWidget {
  const _ViewingSavedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.link_off, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(switch (ref.watch(connectionProvider)) {
              _ when databaseSetAside => context.l10n.earlierChatsSetAside,
              ViewingSaved(radioKey: '') => context.l10n.noRadioYetConnect,
              ViewingSaved(:final error?) => connectionErrorText(
                context.l10n,
                error,
              ),
              _ => context.l10n.noRadioConnectedReadOnly,
            }),
          ),
          TextButton(
            onPressed: () => _openConnect(context),
            child: Text(context.l10n.connect),
          ),
        ],
      ),
    ),
  );
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
                        ? context.l10n.reconnectingToRadio
                        : context.l10n.reconnectingToRadioTry(attempt + 1),
                  ),
                  if (error case final error?)
                    Text(
                      connectionErrorText(context.l10n, error),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ref.read(connectionProvider.notifier).retryNow(),
              child: Text(context.l10n.tryNow),
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
      : Semantics(
          label: context.l10n.unreadCount(count),
          child: ExcludeSemantics(
            child: Badge(
              label: Text(count > 99 ? '99+' : '$count'),
              child: child,
            ),
          ),
        );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
  );
}
