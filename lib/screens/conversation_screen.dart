import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/notifications.dart';
import '../data/data.dart';
import '../radio/radio.dart';

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

  /// Newest message id already marked read.
  int? _readUpTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openThread = ref.read(openThreadProvider.notifier);
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
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Messages that arrived while the app was in the background are read
    // once it's back in front with this chat open.
    if (state == AppLifecycleState.resumed) _markRead();
  }

  void _markRead() {
    final radioKey = ref.read(radioKeyProvider);
    if (radioKey == null || !ref.read(foregroundCheckProvider)()) return;
    ref.read(storeProvider).markRead(radioKey, widget.thread);
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    final state = ref.read(connectionProvider);
    if (text.isEmpty || state is! Connected || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final target = widget.thread.substring(2);
      if (widget.isChannel) {
        await state.sync.sendChannel(int.parse(target), text);
      } else {
        await state.sync.sendDirect(PublicKey.fromHex(target), text);
      }
      _text.clear();
    } on ArgumentError {
      messenger.showSnackBar(
        const SnackBar(content: Text('That message is too long to send.')),
      );
    } on RadioRequestException {
      // The message is stored as failed with a resend option, so don't
      // leave a second copy in the box.
      _text.clear();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The radio could not send it. Hold it to try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showActions(Message message, bool retrying) async {
    final state = ref.read(connectionProvider);
    if (state is! Connected) return;
    final failed = message.status == MessageStatus.failed;
    if (!failed && !retrying) return;
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failed)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Send again'),
                onTap: () => Navigator.pop(context, 'resend'),
              ),
            if (retrying)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Stop trying'),
                onTap: () => Navigator.pop(context, 'stop'),
              ),
          ],
        ),
      ),
    );
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
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final message = messages[messages.length - 1 - i];
                      return _Bubble(
                        message: message,
                        showSender: widget.isChannel,
                        author: _authorName(message.authorPrefix, contacts),
                        retrying: retrying.contains(message.id),
                        onLongPress: message.outgoing
                            ? () => _showActions(
                                message,
                                retrying.contains(message.id),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
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
    required this.showSender,
    this.retrying = false,
    this.onLongPress,
    this.author,
  });

  final Message message;
  final bool showSender;
  final bool retrying;
  final VoidCallback? onLongPress;

  /// Room posts: who wrote it.
  final String? author;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.outgoing;
    final time = TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(message.sentAt * 1000),
    ).format(context);

    final details = [
      time,
      if (!mine && message.kind == MessageKind.channel)
        ?_hops(message.pathLength),
      if (mine && retrying) 'try ${message.attempts}',
      if (mine && message.status == MessageStatus.failed) 'hold to resend',
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
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mine &&
                        (author ?? (showSender ? message.senderName : null))
                    case final name?)
                  Text(
                    name,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(message.body),
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
