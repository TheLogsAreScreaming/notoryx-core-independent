import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/node_look.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';
import 'node_details.dart' show nodeIcon;

/// A node's round avatar: the photo or colour picked for it, or the icon
/// for its type when none was.
class NodeAvatar extends ConsumerWidget {
  const NodeAvatar({
    super.key,
    required this.publicKey,
    required this.name,
    required this.type,
    this.radius,
    this.icon,
  });

  /// The node's key, or a key prefix when only that is known.
  final String publicKey;
  final String name;
  final NodeType type;
  final double? radius;

  /// An icon to use in place of the type icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(nodeLooksProvider).value?[publicKey.toLowerCase()];
    final fallback = icon ?? nodeIcon(type);
    return switch (look) {
      NodePhoto(:final image) => CircleAvatar(
        radius: radius,
        backgroundImage: image,
      ),
      NodeColour(:final colour) => CircleAvatar(
        radius: radius,
        backgroundColor: colour,
        foregroundColor: onColour(colour),
        child: switch (nodeInitials(name)) {
          final initials when type == NodeType.chat && initials.isNotEmpty =>
            Text(initials, style: const TextStyle(fontWeight: FontWeight.w600)),
          _ => Icon(fallback),
        },
      ),
      _ => CircleAvatar(radius: radius, child: Icon(fallback)),
    };
  }
}

/// Lets the person pick a colour or a photo for a node, or clear it.
Future<void> showNodeLookPicker(
  BuildContext context,
  WidgetRef ref, {
  required String publicKey,
  required String name,
  required NodeType type,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) {
    final l10n = context.l10n;
    final names = l10n.nodeColourNames.split(',');
    final store = ref.read(storeProvider);
    Future<void> save(NodeLook? look) async {
      Navigator.pop(sheet);
      await saveNodeLook(store, publicKey, look);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: NodeAvatar(publicKey: publicKey, name: name, type: type),
              title: Text(l10n.nodeLookTitle(name)),
              subtitle: Text(l10n.nodeLookIntro),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < nodeColours.length; i++)
                  Semantics(
                    button: true,
                    label: i < names.length ? names[i] : null,
                    child: InkResponse(
                      onTap: () => save(NodeColour(nodeColours[i])),
                      radius: 26,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: nodeColours[i],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.nodeLookPhoto),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final notPicture = l10n.photoNotImage;
                    final jpeg = await ref.read(nodePhotoPickerProvider)();
                    if (jpeg == null || !sheet.mounted) return;
                    if (jpeg.isEmpty) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(notPicture)),
                      );
                      return;
                    }
                    await save(NodePhoto(jpeg));
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.clear),
                  label: Text(l10n.nodeLookClear),
                  onPressed: () => save(null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);
