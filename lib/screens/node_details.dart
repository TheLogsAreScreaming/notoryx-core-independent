import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/connection.dart';
import '../data/data.dart';
import '../presets/area_presets_provider.dart';
import '../radio/radio.dart';
import 'conversation_screen.dart';
import 'manage_actions.dart';
import 'server_screen.dart';
import 'telemetry_screen.dart';
import 'node_avatar.dart';
import 'node_compass_screen.dart';
import 'node_journal_screen.dart';
import 'route_screen.dart';
import 'terrain_profile_screen.dart';
import 'trace_screen.dart';
import '../l10n/l10n.dart';
import 'follow_screen.dart';

/// What the app knows about one node, whether it's a contact or only heard
/// nearby. Built from either kind of row.
typedef NodeSummary = ({
  String publicKey,
  String name,
  NodeType type,
  double? latitude,
  double? longitude,
  int lastAdvert,
  bool isContact,
  bool favourite,
  int? outPathLength,
});

NodeSummary nodeFromContact(Contact c) => (
  publicKey: c.publicKey,
  name: c.name,
  type: NodeType.fromByte(c.type),
  latitude: c.latitude,
  longitude: c.longitude,
  lastAdvert: c.lastAdvert,
  isContact: true,
  favourite: c.flags & 1 == 1,
  outPathLength: c.outPathLength,
);

NodeSummary nodeFromDiscovered(DiscoveredData d) => (
  publicKey: d.publicKey,
  name: d.name,
  type: NodeType.fromByte(d.type),
  latitude: d.latitude,
  longitude: d.longitude,
  lastAdvert: d.lastAdvert,
  isContact: false,
  favourite: false,
  outPathLength: null,
);

/// The node's kind in [l10n]'s language, or English without it.
String nodeKind(NodeType type, [AppLocalizations? l10n]) => switch (type) {
  NodeType.repeater => l10n?.kindRepeater ?? 'Repeater',
  NodeType.room => l10n?.kindRoomServer ?? 'Room server',
  NodeType.sensor => l10n?.kindSensor ?? 'Sensor',
  _ => l10n?.kindPerson ?? 'Person',
};

IconData nodeIcon(NodeType type) => switch (type) {
  NodeType.repeater => Icons.cell_tower,
  NodeType.room => Icons.forum_outlined,
  NodeType.sensor => Icons.sensors,
  _ => Icons.person_outline,
};

/// "just now", "5 min ago", "3 h ago", "2 days ago". [unixSeconds] is the
/// node's own clock, so a node with a wrong clock can look old or new.
String timeAgo(int unixSeconds, DateTime now, [AppLocalizations? l10n]) {
  if (unixSeconds <= 0) return l10n?.agoNever ?? 'never';
  final seconds = now.millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return l10n?.agoJustNow ?? 'just now';
  if (seconds < 3600) {
    return l10n?.agoMinutes(seconds ~/ 60) ?? '${seconds ~/ 60} min ago';
  }
  if (seconds < 86400) {
    return l10n?.agoHours(seconds ~/ 3600) ?? '${seconds ~/ 3600} h ago';
  }
  final days = seconds ~/ 86400;
  return l10n?.agoDaysLong(days) ??
      (days == 1 ? '1 day ago' : '$days days ago');
}

/// "direct", "2 hops", or "no route yet" from an encoded path length.
String routeText(int? outPathLength, [AppLocalizations? l10n]) {
  if (outPathLength == null || outPathLength == pathUnknown) {
    return l10n?.noRouteYetFlood ?? 'No route yet (messages flood)';
  }
  final hops = outPathLength & 0x3F;
  if (l10n != null) return l10n.routeHops(hops);
  return hops == 0
      ? 'Direct'
      : hops == 1
      ? '1 hop'
      : '$hops hops';
}

/// "1.2 km" or "850 m" between two points.
String distanceText(LatLng a, LatLng b) {
  final metres = const Distance().as(LengthUnit.Meter, a, b);
  return metres < 1000
      ? '${metres.round()} m'
      : '${(metres / 1000).toStringAsFixed(metres < 10000 ? 1 : 0)} km';
}

/// A sheet with a node's details and what you can do with it.
Future<void> showNodeDetails(
  BuildContext context,
  WidgetRef ref,
  NodeSummary node, {
  LatLng? from,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) {
    final position = node.latitude == null
        ? null
        : LatLng(node.latitude!, node.longitude!);
    final theme = Theme.of(sheet);
    void openCompass() {
      Navigator.pop(sheet);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NodeCompassScreen(name: node.name, target: position!),
        ),
      );
    }

    return Consumer(
      builder: (ctx, sheetRef, _) {
        final radioKey = sheetRef.watch(radioKeyProvider);
        final ContactReachability? reachability =
            (node.isContact && node.type == NodeType.chat && radioKey != null)
            ? sheetRef
                  .watch(
                    reachabilityProvider((
                      radioKey: radioKey,
                      publicKey: node.publicKey,
                    )),
                  )
                  .value
            : null;

        final l10n = context.l10n;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: NodeAvatar(
                    publicKey: node.publicKey,
                    name: node.name,
                    type: node.type,
                  ),
                  title: Text(node.name, style: theme.textTheme.titleLarge),
                  subtitle: Text(
                    node.isContact
                        ? nodeKind(node.type, l10n)
                        : l10n.kindHeardNotAdded(nodeKind(node.type, l10n)),
                  ),
                  trailing: node.favourite
                      ? Icon(Icons.star, semanticLabel: l10n.favourite2)
                      : null,
                ),
                _Row(
                  l10n.lastAdvertLabel,
                  timeAgo(node.lastAdvert, DateTime.now(), l10n),
                ),
                if (node.isContact)
                  _Row(l10n.routeLabel, routeText(node.outPathLength, l10n)),
                if (reachability != null)
                  _Row(l10n.reachabilityLabel, switch (reachability) {
                    ContactReachability.twoWay => l10n.reachabilityTwoWay,
                    ContactReachability.theyHeardYou =>
                      l10n.reachabilityTheyHeardYou,
                    ContactReachability.noAnswerYet =>
                      l10n.reachabilityNoAnswerYet,
                  }),
                _Row(
                  context.l10n.positionLabel,
                  position == null
                      ? context.l10n.notShared
                      : '${position.latitude.toStringAsFixed(5)}, '
                            '${position.longitude.toStringAsFixed(5)}',
                  onTap: position == null ? null : openCompass,
                ),
                if (position != null && from != null)
                  _Row(
                    context.l10n.distanceFromYourRadio,
                    distanceText(from, position),
                    onTap: openCompass,
                  ),
                _Row(
                  context.l10n.keyLabel,
                  '${node.publicKey.substring(0, 16)}…',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (node.isContact && node.type == NodeType.chat)
                      FilledButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(context.l10n.message),
                        onPressed: () {
                          Navigator.pop(sheet);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ConversationScreen(
                                thread: Threads.direct(node.publicKey),
                                title: node.name,
                              ),
                            ),
                          );
                        },
                      ),
                    if (node.isContact && position != null)
                      OutlinedButton.icon(
                        key: const Key('follow-node'),
                        icon: const Icon(Icons.radar),
                        label: Text(context.l10n.followButton),
                        onPressed: () {
                          Navigator.pop(sheet);
                          openFollow(
                            context,
                            ref,
                            nodeKey: node.publicKey,
                            name: node.name,
                            lastKnown: position,
                          );
                        },
                      ),
                    if (node.isContact &&
                        (node.type == NodeType.repeater ||
                            node.type == NodeType.room))
                      FilledButton.icon(
                        icon: const Icon(Icons.login),
                        label: Text(context.l10n.open),
                        onPressed: () {
                          Navigator.pop(sheet);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ServerScreen(node: node),
                            ),
                          );
                        },
                      ),
                    if (!node.isContact)
                      FilledButton.icon(
                        icon: const Icon(Icons.person_add_alt),
                        label: Text(context.l10n.addContact),
                        onPressed: () async {
                          Navigator.pop(sheet);
                          final key = ref.read(radioKeyProvider);
                          if (key == null) return;
                          final rows = await ref
                              .read(storeProvider)
                              .watchDiscovered(key)
                              .first;
                          final row = rows
                              .where((d) => d.publicKey == node.publicKey)
                              .firstOrNull;
                          if (row != null && context.mounted) {
                            await addDiscovered(context, ref, row);
                          }
                        },
                      ),
                    if (node.isContact &&
                        node.outPathLength != null &&
                        node.outPathLength != pathUnknown &&
                        (node.outPathLength! & 0x3F > 0 ||
                            node.type == NodeType.repeater ||
                            node.type == NodeType.room))
                      OutlinedButton.icon(
                        icon: const Icon(Icons.route),
                        label: Text(context.l10n.traceRoute),
                        onPressed: () async {
                          Navigator.pop(sheet);
                          final key = ref.read(radioKeyProvider);
                          if (key == null) return;
                          final row = await ref
                              .read(storeProvider)
                              .contact(key, node.publicKey);
                          if (row != null && context.mounted) {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TraceScreen(contact: row),
                              ),
                            );
                          }
                        },
                      ),
                    if (node.isContact)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.alt_route),
                        label: Text(context.l10n.routeButton),
                        onPressed: () async {
                          Navigator.pop(sheet);
                          final key = ref.read(radioKeyProvider);
                          if (key == null) return;
                          final row = await ref
                              .read(storeProvider)
                              .contact(key, node.publicKey);
                          if (row != null && context.mounted) {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RouteScreen(contact: row),
                              ),
                            );
                          }
                        },
                      ),
                    if (position != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.navigation_outlined),
                        label: Text(context.l10n.compassButton),
                        onPressed: openCompass,
                      ),
                    if (position != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.terrain),
                        label: Text(context.l10n.terrainButton),
                        onPressed: () {
                          final radio = ref.read(radioPositionProvider);
                          final start =
                              from ??
                              (radio == null
                                  ? null
                                  : LatLng(radio.lat, radio.lon));
                          if (start == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.terrainNeedsPosition,
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(sheet);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TerrainProfileScreen(
                                from: start,
                                to: position,
                                name: node.name,
                              ),
                            ),
                          );
                        },
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.palette_outlined),
                      label: Text(context.l10n.nodeLookButton),
                      onPressed: () {
                        Navigator.pop(sheet);
                        showNodeLookPicker(
                          context,
                          ref,
                          publicKey: node.publicKey,
                          name: node.name,
                          type: node.type,
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(context.l10n.journalButton),
                      onPressed: () {
                        final key = ref.read(radioKeyProvider);
                        if (key == null) return;
                        Navigator.pop(sheet);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => JournalNodeScreen(
                              radioKey: key,
                              nodeKey: node.publicKey.toLowerCase(),
                            ),
                          ),
                        );
                      },
                    ),
                    if (node.isContact)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.sensors),
                        label: Text(context.l10n.telemetry),
                        onPressed: () {
                          Navigator.pop(sheet);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TelemetryScreen(
                                nodeKey: node.publicKey,
                                name: node.name,
                                type: node.type,
                              ),
                            ),
                          );
                        },
                      ),
                    if (node.isContact)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.more_horiz),
                        label: Text(context.l10n.more),
                        onPressed: () async {
                          Navigator.pop(sheet);
                          final key = ref.read(radioKeyProvider);
                          if (key == null) return;
                          final row = await ref
                              .read(storeProvider)
                              .contact(key, node.publicKey);
                          if (row != null && context.mounted) {
                            await showContactActions(
                              context,
                              ref,
                              contact: row,
                            );
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.onTap});

  final String label;
  final String value;

  /// Opens something about this row, such as the compass for a position.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
          if (onTap != null)
            Icon(
              Icons.navigation_outlined,
              size: 18,
              semanticLabel: context.l10n.compassButton,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: row,
      ),
    );
  }
}
