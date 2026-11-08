import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/blocking.dart';
import '../app/appearance.dart';
import '../app/connection.dart';
import '../app/delivery.dart';
import '../app/notifications.dart';
import '../app/mesh_links.dart';
import '../app/position.dart';
import '../app/reactions.dart';
import '../app/shared_items.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import 'manage_actions.dart';
import 'position_map_screen.dart';
import 'quick_messages_screen.dart';

/// One direct or channel conversation with a box to reply.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    required this.thread,
    required this.title,
    this.isChannel = false,
    super.key,
  });

  final String thread;
  final String title;
  final bool isChannel;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  bool _sending = false;
  late final OpenThread _openThread;
  late final MeshStore _store;

  /// The radio the draft in the box belongs to, once it has been loaded.
  String? _draftRadio;
  Timer? _draftSave;

  /// Newest message id already marked read.
  int? _readUpTo;

  /// The message being replied to, and who sent it.
  ({Message message, String name})? _replyTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openThread = ref.read(openThreadProvider.notifier);
    _store = ref.read(storeProvider);
    _text.addListener(_draftChanged);
    unawaited(_loadDraft());
    // After this frame: providers can't change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openThread.open(widget.thread);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Providers can't change while the tree is being torn down.
    final openThread = _openThread, thread = widget.thread;
    Future(() => openThread.close(thread));
    _flushDraft();
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Messages that arrived while the app was in the background are read
    // once it's back in front with this chat open.
    if (state == AppLifecycleState.resumed) _markRead();
  }

  Future<void> _loadDraft() async {
    final radioKey = ref.read(radioKeyProvider);
    if (radioKey == null) return;
    final draft = await _store.draft(radioKey, widget.thread);
    if (!mounted) return;
    _draftRadio = radioKey;
    if (draft != null && _text.text.isEmpty) {
      _text.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
  }

  /// Saves what's in the box shortly after typing stops.
  void _draftChanged() {
    if (_draftRadio == null) return;
    _draftSave?.cancel();
    _draftSave = Timer(const Duration(milliseconds: 600), _flushDraft);
  }

  void _flushDraft() {
    _draftSave?.cancel();
    _draftSave = null;
    final radioKey = _draftRadio;
    if (radioKey == null) return;
    unawaited(_store.saveDraft(radioKey, widget.thread, _text.text));
  }

  /// Puts [text] in the box, after anything already typed, to check
  /// before sending.
  void _insert(String text) {
    final current = _text.text.trimRight();
    final next = current.isEmpty ? text : '$current $text';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _share(List<Contact> contacts) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('My position'),
              subtitle: const Text('From the phone, or else the radio'),
              onTap: () => Navigator.pop(context, 'position'),
            ),
            ListTile(
              leading: const Icon(Icons.contact_page_outlined),
              title: const Text('A contact'),
              subtitle: const Text('They can add it in one tap'),
              onTap: () => Navigator.pop(context, 'contact'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (choice == 'position') {
      LatLng? here;
      try {
        here = await ref
            .read(phonePositionProvider)()
            .timeout(const Duration(seconds: 15));
      } on Object {
        here = null;
      }
      final state = ref.read(connectionProvider);
      if (here == null && state is Connected) {
        final self = state.radio.self;
        if (self.latitude case final lat? when self.longitude != null) {
          here = LatLng(lat, self.longitude!);
        }
      }
      if (!mounted) return;
      if (here == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No position: turn on location, or set the radio’s position.',
            ),
          ),
        );
        return;
      }
      _insert(positionText(here));
      return;
    }
    final picked = await showDialog<Contact>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Share a contact'),
        children: [
          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No contacts on this radio yet.'),
            ),
          for (final c in contacts)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Text(c.name),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    _insert(
      ContactLink(
        name: picked.name,
        publicKey: PublicKey.fromHex(picked.publicKey),
        type: NodeType.fromByte(picked.type),
      ).url,
    );
  }

  Future<void> _pickQuick() async {
    final pick = await showQuickMessagePicker(context);
    if (pick == null || !mounted) return;
    if (pick.edit) {
      _text.value = TextEditingValue(
        text: pick.text,
        selection: TextSelection.collapsed(offset: pick.text.length),
      );
    } else {
      await _send(pick.text);
    }
  }

  void _markRead() {
    final radioKey = ref.read(radioKeyProvider);
    if (radioKey == null || !ref.read(foregroundCheckProvider)()) return;
    ref.read(storeProvider).markRead(radioKey, widget.thread);
  }

  /// Sends what's in the box (as a reply, when one is chosen), or [quick]
  /// as it is, leaving the box alone.
  Future<void> _send([String? quick]) async {
    final typed = quick == null;
    final typedText = (quick ?? _text.text).trim();
    final state = ref.read(connectionProvider);
    if (typedText.isEmpty || state is! Connected || _sending) return;
    final replyTo = typed ? _replyTo : null;
    final text = replyTo == null
        ? typedText
        : replyText(replyTo.name, typedText);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final target = widget.thread.substring(2);
      if (widget.isChannel) {
        await state.sync.sendChannel(int.parse(target), text);
      } else {
        await state.sync.sendDirect(PublicKey.fromHex(target), text);
      }
      if (typed) _clearBox();
      if (replyTo != null && mounted) setState(() => _replyTo = null);
    } on ArgumentError {
      messenger.showSnackBar(
        const SnackBar(content: Text('That message is too long to send.')),
      );
    } on RadioRequestException {
      // The message is stored as failed with a resend option, so don't
      // leave a second copy in the box.
      if (typed) _clearBox();
      if (replyTo != null && mounted) setState(() => _replyTo = null);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The radio could not send it. Hold it to try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _clearBox() {
    _text.clear();
    _flushDraft();
  }

  /// The contact this direct chat is with, when the radio knows them.
  Contact? _contact(List<Contact> contacts) {
    if (widget.isChannel) return null;
    final key = widget.thread.substring(2);
    for (final c in contacts) {
      if (c.publicKey == key) return c;
    }
    return null;
  }

  Future<void> _showActions(
    Message message,
    String sender, {
    required bool retrying,
    required bool canReply,
    Contact? contact,
  }) async {
    final state = ref.read(connectionProvider);
    final connected = state is Connected;
    final failed = message.status == MessageStatus.failed;
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReply) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: [
                    for (final emoji in quickReactions)
                      IconButton(
                        tooltip: 'React $emoji',
                        onPressed: () => Navigator.pop(context, 'react:$emoji'),
                        icon: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            ],
            if (!message.outgoing)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text('Block $sender'),
                subtitle: Text(
                  message.kind == MessageKind.channel
                      ? 'Hides messages posted under this name, on every '
                            'channel.'
                      : 'Hides their direct messages.',
                ),
                onTap: () => Navigator.pop(context, 'block'),
              ),
            if (message.outgoing)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Delivery details'),
                onTap: () => Navigator.pop(context, 'details'),
              ),
            if (failed && connected)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Send again'),
                onTap: () => Navigator.pop(context, 'resend'),
              ),
            if (retrying && connected)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Stop trying'),
                onTap: () => Navigator.pop(context, 'stop'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action.startsWith('react:')) {
      await _send(reactionText(action.substring(6), message.body));
      return;
    }
    if (action == 'reply') {
      setState(() => _replyTo = (message: message, name: sender));
      return;
    }
    if (action == 'block') {
      final blocking = ref.read(blockingProvider);
      if (message.kind == MessageKind.channel) {
        final name = message.senderName;
        if (name != null) await blocking.blockName(name);
      } else {
        await blocking.blockKey(message.thread.substring(2));
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Blocked $sender.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (message.kind == MessageKind.channel) {
                final name = message.senderName;
                if (name != null) unawaited(blocking.unblockName(name));
              } else {
                unawaited(blocking.unblockKey(message.thread.substring(2)));
              }
            },
          ),
        ),
      );
      return;
    }
    if (action == 'details') {
      await _showDelivery(message, retrying, contact);
      return;
    }
    if (state is! Connected) return;
    try {
      switch (action) {
        case 'resend':
          await state.sync.resend(message.id);
        case 'stop':
          await state.sync.stopTrying(message.id);
      }
    } on RadioRequestException {
      messenger.showSnackBar(
        const SnackBar(content: Text('The radio could not send it.')),
      );
    }
  }

  Future<void> _showDelivery(
    Message message,
    bool retrying,
    Contact? contact,
  ) async {
    final report = deliveryReport(
      message,
      retrying: retrying,
      contact: contact,
    );
    final sent = DateTime.fromMillisecondsSinceEpoch(message.sentAt * 1000);
    final canReset =
        contact != null &&
        contact.outPathLength != pathUnknown &&
        ref.read(connectionProvider) is Connected;
    final messenger = ScaffoldMessenger.of(context);
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.headline),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sent ${MaterialLocalizations.of(context).formatShortDate(sent)} '
                '${TimeOfDay.fromDateTime(sent).format(context)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final line in report.details)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(line),
                ),
            ],
          ),
        ),
        actions: [
          if (canReset)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset route'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    final state = ref.read(connectionProvider);
    if (reset != true || contact == null || state is! Connected) return;
    try {
      await state.sync.resetRoute(PublicKey.fromHex(contact.publicKey));
      messenger.showSnackBar(
        const SnackBar(content: Text('Route reset. The next message floods.')),
      );
    } on RadioRequestException {
      messenger.showSnackBar(
        const SnackBar(content: Text('The radio could not reset the route.')),
      );
    }
  }

  /// A room post's writer: the contact whose key starts with [prefix], or
  /// the prefix itself for someone not in contacts.
  static String? _authorName(String? prefix, List<Contact> contacts) {
    if (prefix == null) return null;
    for (final c in contacts) {
      if (c.publicKey.startsWith(prefix)) return c.name;
    }
    return 'Member $prefix';
  }

  @override
  Widget build(BuildContext context) {
    final radioKey = ref.watch(radioKeyProvider);
    final chatScale = ref.watch(appearanceProvider.select((a) => a.chatScale));
    final connected = ref.watch(connectionProvider) is Connected;
    final messages = radioKey == null
        ? const <Message>[]
        : ref
                  .watch(
                    threadProvider((radioKey: radioKey, thread: widget.thread)),
                  )
                  .value ??
              const <Message>[];
    final retrying = ref.watch(retryingProvider).value ?? const <int>{};
    final contacts = radioKey == null
        ? const <Contact>[]
        : ref.watch(contactsProvider(radioKey)).value ?? const <Contact>[];
    final muted =
        radioKey != null &&
        (ref.watch(mutedThreadsProvider(radioKey)).value ?? const {}).contains(
          widget.thread,
        );
    // Everything on screen is read, including messages that land while the
    // chat is open.
    final newest = messages.isEmpty ? null : messages.last.id;
    if (newest != null && newest != _readUpTo) {
      _readUpTo = newest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markRead();
      });
    }
    // A direct thread keyed by prefix means the sender isn't a contact yet,
    // so there is no full key to reply to.
    final canReply =
        connected && (widget.isChannel || widget.thread.length == 2 + 64);
    final connection = ref.watch(connectionProvider);
    final selfName = connection is Connected
        ? connection.radio.self.name
        : 'Me';
    String senderOf(Message m) {
      if (m.outgoing) return selfName;
      return _authorName(m.authorPrefix, contacts) ??
          (widget.isChannel ? m.senderName ?? 'Someone' : widget.title);
    }

    final blocked = ref.watch(blockListProvider).value ?? const BlockList();
    final directKey = widget.isChannel ? null : widget.thread.substring(2);
    final threadBlocked = directKey != null && blocked.keys.contains(directKey);
    final items = chatItems([
      for (final m in messages)
        if (!blocked.blocks(m)) m,
    ], senderOf: senderOf);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (radioKey != null)
            IconButton(
              tooltip: muted ? 'Unmute' : 'Mute notifications',
              icon: Icon(
                muted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
              ),
              onPressed: () => ref
                  .read(storeProvider)
                  .setMuted(radioKey, widget.thread, !muted),
            ),
        ],
      ),
      body: Column(
        children: [
          if (threadBlocked)
            MaterialBanner(
              content: Text(
                'You blocked ${widget.title}. Their messages are hidden.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(blockingProvider).unblockKey(directKey),
                  child: const Text('Unblock'),
                ),
              ],
            ),
          if (!widget.isChannel)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Direct messages only arrive if ${widget.title} has added you '
                'as a contact.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[items.length - 1 - i];
                      final message = item.message;
                      final replyTo = item.replyTo;
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(
                            MediaQuery.textScalerOf(context).scale(1) *
                                chatScale,
                          ),
                        ),
                        child: _Bubble(
                          message: message,
                          body: item.replyText ?? message.body,
                          showSender: widget.isChannel,
                          author: _authorName(message.authorPrefix, contacts),
                          replyTo: replyTo == null
                              ? null
                              : (name: senderOf(replyTo), body: replyTo.body),
                          reactions: item.reactions,
                          mentionsMe:
                              !message.outgoing &&
                              mentions(
                                message.body,
                                connection is Connected
                                    ? connection.radio.self.name
                                    : null,
                              ),
                          onShowPosition: switch (sharedPosition(
                            message.body,
                          )) {
                            final p? => () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PositionMapScreen(
                                  position: p,
                                  label: senderOf(message),
                                ),
                              ),
                            ),
                            null => null,
                          },
                          link: message.outgoing
                              ? null
                              : sharedLink(message.body),
                          onAddLink: (link) => addLink(context, ref, link),
                          retrying: retrying.contains(message.id),
                          onReact: canReply && !_sending
                              ? (emoji) =>
                                    _send(reactionText(emoji, message.body))
                              : null,
                          onLongPress: message.outgoing || canReply || connected
                              ? () => _showActions(
                                  message,
                                  senderOf(message),
                                  retrying: retrying.contains(message.id),
                                  canReply: canReply,
                                  contact: _contact(contacts),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          if (_replyTo case final reply? when canReply)
            _ReplyBanner(
              name: reply.name,
              body: reply.message.body,
              onCancel: () => setState(() => _replyTo = null),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Quick messages',
                    onPressed: canReply && !_sending ? _pickQuick : null,
                    icon: const Icon(Icons.bolt),
                  ),
                  IconButton(
                    tooltip: 'Share position or contact',
                    onPressed: canReply && !_sending
                        ? () => _share(contacts)
                        : null,
                    icon: const Icon(Icons.add_location_alt_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: canReply,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: canReply
                            ? 'Message'
                            : connected
                            ? 'Add this sender as a contact to reply'
                            : radioKey != null
                            ? 'Waiting for the radio to reconnect'
                            : 'Not connected',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: canReply && !_sending ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.body,
    required this.showSender,
    this.retrying = false,
    this.onLongPress,
    this.onReact,
    this.author,
    this.replyTo,
    this.reactions = const [],
    this.mentionsMe = false,
    this.onShowPosition,
    this.link,
    this.onAddLink,
  });

  /// Whether this mentions you; such messages stand out.
  final bool mentionsMe;

  /// Opens the position this message shares; null when it shares none.
  final VoidCallback? onShowPosition;

  /// A contact or channel this message shares, and how to add it.
  final MeshLink? link;
  final void Function(MeshLink link)? onAddLink;

  final Message message;

  /// The text shown: a reply's leading mention is left off.
  final String body;
  final bool showSender;
  final bool retrying;
  final VoidCallback? onLongPress;

  /// Adds the same reaction; null when sending isn't possible.
  final void Function(String emoji)? onReact;

  /// The message this one replies to.
  final ({String name, String body})? replyTo;
  final List<ReactionCount> reactions;

  /// Room posts: who wrote it.
  final String? author;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.outgoing;
    final shownName = mine
        ? null
        : author ?? (showSender ? message.senderName : null);
    final time = TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(message.sentAt * 1000),
    ).format(context);

    final details = [
      time,
      if (!mine && message.kind == MessageKind.channel)
        ?_hops(message.pathLength),
      if (mine && retrying) 'try ${message.attempts}',
      if (mine && message.status == MessageStatus.failed) 'hold for details',
    ].join(' · ');

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: mine
                  ? scheme.primaryContainer
                  : mentionsMe
                  ? scheme.tertiaryContainer
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: mentionsMe
                  ? Border.all(color: scheme.tertiary, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mentionsMe)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alternate_email,
                        size: 14,
                        color: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Mentions you',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                    ],
                  ),
                if (shownName case final name?)
                  Text(
                    name,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (replyTo case final quoted?)
                  _Quote(name: quoted.name, body: quoted.body),
                Text(body),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wraps rather than overflowing a narrow bubble.
                    Flexible(
                      child: Text(
                        details,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      _StatusIcon(message.status),
                    ],
                  ],
                ),
                if (onShowPosition != null || link != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (onShowPosition case final show?)
                          ActionChip(
                            avatar: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Show on map'),
                            onPressed: show,
                          ),
                        if (link case final link?)
                          ActionChip(
                            avatar: Icon(
                              link is ChannelLink
                                  ? Icons.tag
                                  : Icons.person_add_alt,
                              size: 18,
                            ),
                            label: Text(switch (link) {
                              ChannelLink(:final name) => 'Join $name',
                              ContactLink(:final name) => 'Add $name',
                            }),
                            onPressed: onAddLink == null
                                ? null
                                : () => onAddLink!(link),
                          ),
                      ],
                    ),
                  ),
                if (reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final r in reactions)
                          _ReactionChip(
                            reaction: r,
                            onTap: r.mine || onReact == null
                                ? null
                                : () => onReact!(r.emoji),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "direct", "1 hop", "3 hops" for a channel message's path.
  static String? _hops(int? pathLength) {
    if (pathLength == null) return null;
    if (pathLength == 0xFF) return 'direct';
    final hops = pathLength & 0x3F;
    return switch (hops) {
      0 => 'direct',
      1 => '1 hop',
      _ => '$hops hops',
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status);

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      MessageStatus.pending => (Icons.schedule, 'Sending'),
      MessageStatus.sent => (Icons.check, 'Sent'),
      MessageStatus.delivered => (Icons.done_all, 'Delivered'),
      MessageStatus.failed => (Icons.error_outline, 'Not sent'),
      MessageStatus.received => (Icons.check, 'Received'),
    };
    return Semantics(
      label: label,
      child: Icon(
        icon,
        size: 14,
        color: status == MessageStatus.failed
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }
}

/// The message a reply answers, shown small above the reply.
class _Quote extends StatelessWidget {
  const _Quote({required this.name, required this.body});

  final String name;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'In reply to $name: $body',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: scheme.primary, width: 3)),
          color: scheme.surface.withValues(alpha: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply, size: 14, color: scheme.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reaction, this.onTap});

  final ReactionCount reaction;

  /// Adds this reaction too; null when it's already yours or can't be sent.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = reaction.who.join(', ');
    final yours = reaction.mine ? ', including you' : '';
    return Semantics(
      button: onTap != null,
      label: '${reaction.emoji} ${reaction.count}: $names$yours',
      excludeSemantics: true,
      child: Tooltip(
        message: names,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 28, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: reaction.mine ? scheme.primary : scheme.outlineVariant,
                width: reaction.mine ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reaction.emoji),
                if (reaction.count > 1) ...[
                  const SizedBox(width: 4),
                  Text('${reaction.count}'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown above the box while a reply is being written.
class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({
    required this.name,
    required this.body,
    required this.onCancel,
  });

  final String name;
  final String body;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(Icons.reply, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to $name',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cancel reply',
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
