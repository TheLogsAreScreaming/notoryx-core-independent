import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/connection.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'conversation_screen.dart';
import 'manage_actions.dart';
import 'server_screen.dart';

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

String nodeKind(NodeType type) => switch (type) {
  NodeType.repeater => 'Repeater',
  NodeType.room => 'Room server',
  NodeType.sensor => 'Sensor',
  _ => 'Person',
};

IconData nodeIcon(NodeType type) => switch (type) {
  NodeType.repeater => Icons.cell_tower,
  NodeType.room => Icons.forum_outlined,
  NodeType.sensor => Icons.sensors,
  _ => Icons.person_outline,
};

/// "just now", "5 min ago", "3 h ago", "2 days ago". [unixSeconds] is the
/// node's own clock, so a node with a wrong clock can look old or new.
String timeAgo(int unixSeconds, DateTime now) {
  if (unixSeconds <= 0) return 'never';
  final seconds = now.millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  if (seconds < 86400) return '${seconds ~/ 3600} h ago';
  final days = seconds ~/ 86400;
  return days == 1 ? '1 day ago' : '$days days ago';
}

/// "direct", "2 hops", or "no route yet" from an encoded path length.
String routeText(int? outPathLength) {
  if (outPathLength == null || outPathLength == pathUnknown) {
    return 'No route yet (messages flood)';
  }
  final hops = outPathLength & 0x3F;
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(nodeIcon(node.type))),
              title: Text(node.name, style: theme.textTheme.titleLarge),
              subtitle: Text(
                '${nodeKind(node.type)}'
                '${node.isContact ? '' : ' · heard nearby, not added'}',
              ),
              trailing: node.favourite
                  ? const Icon(Icons.star, semanticLabel: 'Favourite')
                  : null,
            ),
            _Row('Last advert', timeAgo(node.lastAdvert, DateTime.now())),
            if (node.isContact) _Row('Route', routeText(node.outPathLength)),
            _Row(
              'Position',
              position == null
                  ? 'Not shared'
                  : '${position.latitude.toStringAsFixed(5)}, '
                        '${position.longitude.toStringAsFixed(5)}',
            ),
            if (position != null && from != null)
              _Row('Distance from your radio', distanceText(from, position)),
            _Row('Key', '${node.publicKey.substring(0, 16)}…'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (node.isContact && node.type == NodeType.chat)
                  FilledButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
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
                if (node.isContact &&
                    (node.type == NodeType.repeater ||
                        node.type == NodeType.room))
                  FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Open'),
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
                    label: const Text('Add contact'),
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
                if (node.isContact)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.more_horiz),
                    label: const Text('More'),
                    onPressed: () async {
                      Navigator.pop(sheet);
                      final key = ref.read(radioKeyProvider);
                      if (key == null) return;
                      final row = await ref
                          .read(storeProvider)
                          .contact(key, node.publicKey);
                      if (row != null && context.mounted) {
                        await showContactActions(context, ref, contact: row);
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
