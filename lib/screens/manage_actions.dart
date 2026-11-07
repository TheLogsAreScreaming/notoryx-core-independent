import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/mesh_links.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'qr_widgets.dart';

/// The live sync, or null with a notice when the radio isn't connected.
MeshSync? _syncOrNotice(BuildContext context, WidgetRef ref) {
  final state = ref.read(connectionProvider);
  if (state is Connected) return state.sync;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Connect to the radio first.')));
  return null;
}

/// Runs a radio change and reports failures in a snackbar.
Future<bool> _run(
  BuildContext context,
  Future<void> Function() action, {
  String? done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } on ChannelsFull catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e Leave one first.')));
  } on RadioRequestException {
    messenger.showSnackBar(
      const SnackBar(content: Text('The radio could not make that change.')),
    );
  }
  return false;
}

/// Asks for one line of text. Returns null if cancelled or left empty.
Future<String?> _ask(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String initial = '',
  String action = 'OK',
  bool pasteButton = false,
}) async {
  final value = await showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      title: title,
      label: label,
      hint: hint,
      initial: initial,
      action: action,
      pasteButton: pasteButton,
    ),
  );
  return value == null || value.isEmpty ? null : value;
}

/// A one-field dialog. It owns its text controller, so the controller lives
/// until the closing animation has finished.
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.action,
    required this.pasteButton,
    this.hint,
  });

  final String title;
  final String label;
  final String? hint;
  final String initial;
  final String action;
  final bool pasteButton;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: widget.pasteButton
            ? IconButton(
                tooltip: 'Paste',
                icon: const Icon(Icons.content_paste),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  _controller.text = data?.text ?? '';
                },
              )
            : null,
      ),
      onSubmitted: (_) => _done(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _done, child: Text(widget.action)),
    ],
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> _pick(
  BuildContext context,
  List<(IconData, String, String)> options,
) => showModalBottomSheet<String>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (icon, label, value) in options)
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.pop(context, value),
          ),
      ],
    ),
  ),
);

// Chats tab

/// The Chats tab's + button.
Future<void> showAddChannel(BuildContext context, WidgetRef ref) async {
  final choice = await _pick(context, [
    (Icons.tag, 'Join a #hashtag channel', 'hashtag'),
    (Icons.lock_outline, 'Create a private channel', 'private'),
    (Icons.link, 'Add from a link', 'link'),
    if (canScanQr) (Icons.qr_code_scanner, 'Scan a QR code', 'scan'),
  ]);
  if (choice == null || !context.mounted) return;
  if (choice == 'link') return addFromLink(context, ref);
  if (choice == 'scan') return addFromQr(context, ref);
  final sync = _syncOrNotice(context, ref);
  if (sync == null) return;

  if (choice == 'hashtag') {
    final input = await _ask(
      context,
      title: 'Join a #hashtag channel',
      label: 'Channel name',
      hint: '#hiking',
      action: 'Join',
    );
    if (input == null || !context.mounted) return;
    final name = hashtagName(input);
    await _run(
      context,
      () => sync.addChannel(name, hashtagSecret(name)),
      done: 'Joined $name',
    );
    return;
  }

  final name = await _ask(
    context,
    title: 'Create a private channel',
    label: 'Channel name',
    action: 'Create',
  );
  if (name == null || !context.mounted) return;
  final secret = randomChannelSecret();
  final ok = await _run(context, () => sync.addChannel(name, secret));
  if (!ok || !context.mounted) return;
  await _shareChannel(context, ChannelLink(name: name, secret: secret));
}

Future<void> _shareChannel(BuildContext context, ChannelLink link) =>
    showLinkSheet(
      context,
      title: link.name,
      link: link,
      warning:
          'Anyone with this code or link can read and write in the channel. '
          'Share it only with people you trust.',
    );

/// Holding a channel in the Chats tab.
Future<void> showChannelActions(
  BuildContext context,
  WidgetRef ref, {
  required String radioKey,
  required Channel channel,
}) async {
  final store = ref.read(storeProvider);
  final thread = Threads.channel(channel.slot);
  final muted = await store.isMuted(radioKey, thread);
  if (!context.mounted) return;
  final choice = await _pick(context, [
    muted
        ? (Icons.notifications_active_outlined, 'Unmute', 'mute')
        : (Icons.notifications_off_outlined, 'Mute notifications', 'mute'),
    (Icons.share_outlined, 'Share channel link', 'share'),
    (Icons.edit_outlined, 'Rename', 'rename'),
    (Icons.logout, 'Leave channel', 'leave'),
  ]);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'mute':
      await store.setMuted(radioKey, thread, !muted);
    case 'share':
      await _shareChannel(
        context,
        ChannelLink(name: channel.name, secret: channel.secret),
      );
    case 'rename':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      final name = await _ask(
        context,
        title: 'Rename channel',
        label: 'Name',
        initial: channel.name,
        action: 'Rename',
      );
      if (name == null || !context.mounted) return;
      await _run(context, () => sync.renameChannel(channel.slot, name));
    case 'leave':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      final sure = await _confirm(
        context,
        'Leave ${channel.name}?',
        'The radio stops receiving this channel. Messages already here stay. '
            'You can join again with its name or link.',
        'Leave',
      );
      if (!sure || !context.mounted) return;
      await _run(
        context,
        () => sync.leaveChannel(channel.slot),
        done: 'Left ${channel.name}',
      );
  }
}

// Links

/// Adds a channel or contact from a pasted `meshcore://` link.
Future<void> addFromLink(BuildContext context, WidgetRef ref) async {
  final text = await _ask(
    context,
    title: 'Add from a link',
    label: 'meshcore:// link',
    action: 'Add',
    pasteButton: true,
  );
  if (text == null || !context.mounted) return;
  await _addLink(context, ref, MeshLink.parse(text));
}

/// Scans a QR code and adds the channel or contact in it.
Future<void> addFromQr(BuildContext context, WidgetRef ref) async {
  final link = await scanMeshLink(context);
  if (link == null || !context.mounted) return;
  await _addLink(context, ref, link);
}

Future<void> _addLink(
  BuildContext context,
  WidgetRef ref,
  MeshLink? link,
) async {
  if (link == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('That isn’t a MeshCore channel or contact link.'),
      ),
    );
    return;
  }
  final sync = _syncOrNotice(context, ref);
  if (sync == null) return;
  switch (link) {
    case ChannelLink(:final name, :final secret):
      await _run(
        context,
        () => sync.addChannel(name, secret),
        done: 'Added $name',
      );
    case ContactLink(:final name, :final publicKey, :final type):
      await _run(
        context,
        () => sync.addContact(publicKey: publicKey, name: name, type: type),
        done: 'Added $name',
      );
  }
}

// Contacts tab

/// The Contacts tab's + button.
Future<void> showContactsMenu(
  BuildContext context,
  WidgetRef ref, {
  required String radioName,
  required String radioKey,
}) async {
  final choice = await _pick(context, [
    (Icons.link, 'Add from a link', 'link'),
    if (canScanQr) (Icons.qr_code_scanner, 'Scan a QR code', 'scan'),
    (Icons.qr_code_2, 'Share my contact', 'share'),
    (Icons.campaign_outlined, 'Advertise to nearby nodes', 'advert'),
    (Icons.public, 'Advertise across the mesh', 'flood'),
  ]);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'link':
      await addFromLink(context, ref);
    case 'scan':
      await addFromQr(context, ref);
    case 'share':
      final link = ContactLink(
        name: radioName,
        publicKey: PublicKey.fromHex(radioKey),
        type: NodeType.chat,
      );
      await showLinkSheet(context, title: 'My contact', link: link);
    case 'advert' || 'flood':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      final flood = choice == 'flood';
      await _run(
        context,
        () => sync.sendAdvert(flood: flood),
        done: flood
            ? 'Advert sent across the mesh'
            : 'Advert sent to nearby nodes',
      );
  }
}

/// Holding a contact in the Contacts tab.
Future<void> showContactActions(
  BuildContext context,
  WidgetRef ref, {
  required Contact contact,
}) async {
  final favourite = contact.flags & 1 == 1;
  final choice = await _pick(context, [
    favourite
        ? (Icons.star, 'Remove from favourites', 'favourite')
        : (Icons.star_border, 'Add to favourites', 'favourite'),
    (Icons.share_outlined, 'Share contact link', 'share'),
    (Icons.person_remove_outlined, 'Remove contact', 'remove'),
  ]);
  if (choice == null || !context.mounted) return;
  final key = PublicKey.fromHex(contact.publicKey);
  switch (choice) {
    case 'share':
      final link = ContactLink(
        name: contact.name,
        publicKey: key,
        type: NodeType.fromByte(contact.type),
      );
      await showLinkSheet(context, title: contact.name, link: link);
    case 'favourite':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      await _run(context, () => sync.setFavourite(key, !favourite));
    case 'remove':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      final sure = await _confirm(
        context,
        'Remove ${contact.name}?',
        'The radio forgets this contact. Chats already here stay, and you '
            'can add them again when they advertise.',
        'Remove',
      );
      if (!sure || !context.mounted) return;
      await _run(
        context,
        () => sync.removeContact(key),
        done: 'Removed ${contact.name}',
      );
  }
}

/// Adds a node from "heard nearby".
Future<void> addDiscovered(
  BuildContext context,
  WidgetRef ref,
  DiscoveredData node,
) async {
  final sync = _syncOrNotice(context, ref);
  if (sync == null) return;
  await _run(
    context,
    () => sync.addContact(
      publicKey: PublicKey.fromHex(node.publicKey),
      name: node.name,
      type: NodeType.fromByte(node.type),
      latitude: node.latitude,
      longitude: node.longitude,
      lastAdvert: node.lastAdvert,
    ),
    done: 'Added ${node.name}',
  );
}
