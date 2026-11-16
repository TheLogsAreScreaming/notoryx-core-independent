import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/contact_room.dart';
import '../app/mesh_links.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'trusted_console_screen.dart';
import 'channel_directory_screen.dart';
import 'qr_widgets.dart';
import '../l10n/l10n.dart';

/// The live sync, or null with a notice when the radio isn't connected.
MeshSync? _syncOrNotice(BuildContext context, WidgetRef ref) {
  final state = ref.read(connectionProvider);
  if (state is Connected) return state.sync;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.connectToTheRadioFirst)));
  return null;
}

/// Runs a radio change and reports failures in a snackbar.
Future<bool> _run(
  BuildContext context,
  Future<void> Function() action, {
  String? done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await action();
    if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } on ChannelsFull catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.leaveOneFirst(e))));
  } on RadioRequestException {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.theRadioCouldNotMakeThat)),
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
  String? action,
  bool pasteButton = false,
}) async {
  final value = await showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      title: title,
      label: label,
      hint: hint,
      initial: initial,
      action: action ?? MaterialLocalizations.of(context).okButtonLabel,
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
                tooltip: context.l10n.paste,
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
        child: Text(context.l10n.cancel),
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
            child: Text(context.l10n.cancel),
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
    (Icons.travel_explore, context.l10n.findChannels, 'find'),
    (Icons.tag, context.l10n.joinHashtagChannel, 'hashtag'),
    (Icons.lock_outline, context.l10n.createPrivateChannel, 'private'),
    (Icons.link, context.l10n.addFromALink, 'link'),
    if (canScanQr) (Icons.qr_code_scanner, context.l10n.scanAQRCode, 'scan'),
  ]);
  if (choice == null || !context.mounted) return;
  if (choice == 'find') {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChannelDirectoryScreen()),
    );
    return;
  }

  if (choice == 'link') return addFromLink(context, ref);
  if (choice == 'scan') return addFromQr(context, ref);
  final sync = _syncOrNotice(context, ref);
  if (sync == null) return;

  if (choice == 'hashtag') {
    final input = await _ask(
      context,
      title: context.l10n.joinHashtagChannel,
      label: context.l10n.channelName,
      hint: '#hiking',
      action: context.l10n.join,
    );
    if (input == null || !context.mounted) return;
    await joinHashtag(context, ref, input);
    return;
  }

  final name = await _ask(
    context,
    title: context.l10n.createPrivateChannel,
    label: context.l10n.channelName,
    action: context.l10n.create,
  );
  if (name == null || !context.mounted) return;
  final secret = randomChannelSecret();
  final ok = await _run(context, () => sync.addChannel(name, secret));
  if (!ok || !context.mounted) return;
  await _shareChannel(context, ChannelLink(name: name, secret: secret));
}

/// Joins the hashtag channel [input] (with or without the #).
Future<bool> joinHashtag(
  BuildContext context,
  WidgetRef ref,
  String input,
) async {
  final sync = _syncOrNotice(context, ref);
  if (sync == null) return false;
  final name = hashtagName(input);
  return _run(
    context,
    () => sync.addChannel(name, hashtagSecret(name)),
    done: context.l10n.joinedChannel(name),
  );
}

Future<void> _shareChannel(BuildContext context, ChannelLink link) =>
    showLinkSheet(
      context,
      title: link.name,
      link: link,
      warning: context.l10n.channelLinkWarning,
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
        ? (Icons.notifications_active_outlined, context.l10n.unmuteChat, 'mute')
        : (
            Icons.notifications_off_outlined,
            context.l10n.muteNotifications,
            'mute',
          ),
    (Icons.share_outlined, context.l10n.shareChannelLink, 'share'),
    (Icons.edit_outlined, context.l10n.renameAction, 'rename'),
    (Icons.logout, context.l10n.leaveChannel, 'leave'),
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
        title: context.l10n.renameChannel,
        label: context.l10n.zoneName,
        initial: channel.name,
        action: context.l10n.renameAction,
      );
      if (name == null || !context.mounted) return;
      await _run(context, () => sync.renameChannel(channel.slot, name));
    case 'leave':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      final sure = await _confirm(
        context,
        context.l10n.leaveChannelQuestion(channel.name),
        context.l10n.leaveChannelBody,
        context.l10n.leaveAction,
      );
      if (!sure || !context.mounted) return;
      await _run(
        context,
        () => sync.leaveChannel(channel.slot),
        done: context.l10n.leftChannel(channel.name),
      );
  }
}

// Links

/// Adds a channel or contact from a pasted `meshcore://` link.
Future<void> addFromLink(BuildContext context, WidgetRef ref) async {
  final text = await _ask(
    context,
    title: context.l10n.addFromALink,
    label: context.l10n.linkAdvertOrKey,
    action: context.l10n.add,
    pasteButton: true,
  );
  if (text == null || !context.mounted) return;
  await addLink(context, ref, MeshLink.parse(text));
}

/// Scans a QR code and adds the channel or contact in it.
Future<void> addFromQr(BuildContext context, WidgetRef ref) async {
  final link = await scanMeshLink(context);
  if (link == null || !context.mounted) return;
  await addLink(context, ref, link);
}

/// Adds the contact or joins the channel in [link].
Future<void> addLink(
  BuildContext context,
  WidgetRef ref,
  MeshLink? link,
) async {
  if (link == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.thatIsnTAMeshCoreLink)));
    return;
  }
  final sync = _syncOrNotice(context, ref);
  if (sync == null) return;
  switch (link) {
    case ChannelLink(:final name, :final secret):
      await _run(
        context,
        () => sync.addChannel(name, secret),
        done: context.l10n.added(name),
      );
    case AdvertLink(:final packet):
      await _run(
        context,
        () => sync.importAdvert(packet),
        done: context.l10n.contactAdded,
      );
    case ContactLink(:final name, :final publicKey, :final type):
      await _addMakingRoom(
        context,
        ref,
        sync,
        name,
        () => sync.addContact(publicKey: publicKey, name: name, type: type),
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
    (Icons.link, context.l10n.addFromALink, 'link'),
    if (canScanQr) (Icons.qr_code_scanner, context.l10n.scanAQRCode, 'scan'),
    (Icons.qr_code_2, context.l10n.shareMyContact, 'share'),
    (Icons.campaign_outlined, context.l10n.advertiseNearby, 'advert'),
    (Icons.public, context.l10n.advertiseAcrossMesh, 'flood'),
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
      await showLinkSheet(context, title: context.l10n.myContact, link: link);
    case 'advert' || 'flood':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      final flood = choice == 'flood';
      await _run(
        context,
        () => sync.sendAdvert(flood: flood),
        done: flood
            ? context.l10n.advertSentAcrossMesh
            : context.l10n.advertSentNearby,
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
  final isPerson = contact.type == NodeType.chat.value;
  final remoteAllowed = contact.flags & contactFlagRemoteCommands != 0;
  final choice = await _pick(context, [
    favourite
        ? (Icons.star, context.l10n.removeFromFavourites, 'favourite')
        : (Icons.star_border, context.l10n.addToFavourites, 'favourite'),
    (Icons.share_outlined, context.l10n.shareContactLink, 'share'),
    (Icons.update, context.l10n.forgetLastAdvertTime, 'forget'),
    if (isPerson) ...[
      (Icons.terminal, context.l10n.useTheirCommandLine, 'their_cli'),
      remoteAllowed
          ? (Icons.lock, context.l10n.stopThemUsingMyCli, 'allow_cli')
          : (Icons.lock_open, context.l10n.letThemUseMyCli, 'allow_cli'),
    ],
    (Icons.person_remove_outlined, context.l10n.removeContact, 'remove'),
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
    case 'their_cli':
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TrustedConsoleScreen(contact: contact),
        ),
      );
    case 'allow_cli':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      if (!remoteAllowed) {
        final sure = await _confirm(
          context,
          context.l10n.giveControlTitle(contact.name),
          context.l10n.giveControlBody,
          context.l10n.allow,
        );
        if (!sure || !context.mounted) return;
      }
      await _run(
        context,
        () => sync.setRemoteCommandsAllowed(key, allowed: !remoteAllowed),
        done: remoteAllowed
            ? context.l10n.cliRevoked(contact.name)
            : context.l10n.cliGranted(contact.name),
      );
    case 'forget':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      await _run(
        context,
        () => sync.forgetLastAdvert(key),
        done: context.l10n.nextAdvertAccepted(contact.name),
      );
    case 'remove':
      final sync = _syncOrNotice(context, ref);
      if (sync == null) return;
      final sure = await _confirm(
        context,
        context.l10n.removeNameQuestion(contact.name),
        context.l10n.removeContactBody,
        context.l10n.remove,
      );
      if (!sure || !context.mounted) return;
      await _run(
        context,
        () => sync.removeContact(key),
        done: context.l10n.removedName(contact.name),
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
  await _addMakingRoom(
    context,
    ref,
    sync,
    node.name,
    () => sync.addContact(
      publicKey: PublicKey.fromHex(node.publicKey),
      name: node.name,
      type: NodeType.fromByte(node.type),
      latitude: node.latitude,
      longitude: node.longitude,
      lastAdvert: node.lastAdvert,
    ),
  );
}

/// Asks which of [heard] to add, up to [room] of them, and adds them.
Future<void> addSeveralDiscovered(
  BuildContext context,
  WidgetRef ref,
  List<DiscoveredData> heard,
  int room,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final picked = await showDialog<List<DiscoveredData>>(
    context: context,
    builder: (_) => _AddSeveralDialog(heard: heard, room: room),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  final sync = _syncOrNotice(context, ref);
  if (sync == null) return;
  var added = 0;
  try {
    for (final node in picked) {
      await sync.addContact(
        publicKey: PublicKey.fromHex(node.publicKey),
        name: node.name,
        type: NodeType.fromByte(node.type),
        latitude: node.latitude,
        longitude: node.longitude,
        lastAdvert: node.lastAdvert,
      );
      added++;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.added2(added))));
  } on RadioRequestException {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.addedOfTheRadioRefusedThe(added, picked.length)),
      ),
    );
  }
}

class _AddSeveralDialog extends StatefulWidget {
  const _AddSeveralDialog({required this.heard, required this.room});

  final List<DiscoveredData> heard;
  final int room;

  @override
  State<_AddSeveralDialog> createState() => _AddSeveralDialogState();
}

class _AddSeveralDialogState extends State<_AddSeveralDialog> {
  late final Set<DiscoveredData> _picked = widget.heard
      .take(widget.room)
      .toSet();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.addContactsOfFree(_picked.length, widget.room)),
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final node in widget.heard)
            CheckboxListTile(
              value: _picked.contains(node),
              title: Text(node.name),
              onChanged:
                  !_picked.contains(node) && _picked.length >= widget.room
                  ? null
                  : (on) => setState(
                      () =>
                          on == true ? _picked.add(node) : _picked.remove(node),
                    ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: _picked.isEmpty
            ? null
            : () => Navigator.of(context).pop(_picked.toList()),
        child: Text(context.l10n.add),
      ),
    ],
  );
}

/// Adds a contact. When the radio's table is full, offers to swap out the
/// contact heard longest ago (never a favourite) and tries once more.
Future<void> _addMakingRoom(
  BuildContext context,
  WidgetRef ref,
  MeshSync sync,
  String name,
  Future<void> Function() add,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await add();
    messenger.showSnackBar(SnackBar(content: Text(l10n.added(name))));
    return;
  } on RadioRejected catch (e) {
    if (e.code != RadioErrorCode.tableFull) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotMakeThat)),
      );
      return;
    }
  } on RadioRequestException {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.theRadioCouldNotMakeThat)),
    );
    return;
  }
  final radioKey = ref.read(radioKeyProvider);
  final contacts = radioKey == null
      ? const <Contact>[]
      : await ref.read(storeProvider).watchContacts(radioKey).first;
  final out = removalCandidates(contacts).firstOrNull;
  if (!context.mounted) return;
  if (out == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.theRadioSContactsAreFull)),
    );
    return;
  }
  final swap = await _confirm(
    context,
    context.l10n.contactsAreFull,
    context.l10n.swapContactBody(
      name,
      out.name,
      lastHeard(out.lastAdvert, DateTime.now(), context.l10n),
    ),
    context.l10n.swapAction,
  );
  if (!swap || !context.mounted) return;
  await _run(context, () async {
    await sync.removeContact(PublicKey.fromHex(out.publicKey));
    await add();
  }, done: context.l10n.swappedContacts(out.name, name));
}
