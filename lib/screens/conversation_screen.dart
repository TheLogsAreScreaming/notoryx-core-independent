import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
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

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
      messenger.showSnackBar(
        const SnackBar(content: Text('The radio could not send it.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radioKey = ref.watch(radioKeyProvider);
    final connected = radioKey != null;
    final messages = radioKey == null
        ? const <Message>[]
        : ref
                  .watch(
                    threadProvider((radioKey: radioKey, thread: widget.thread)),
                  )
                  .value ??
              const <Message>[];
    // A direct thread keyed by prefix means the sender isn't a contact yet,
    // so there is no full key to reply to.
    final canReply =
        connected && (widget.isChannel || widget.thread.length == 2 + 64);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _Bubble(
                      message: messages[messages.length - 1 - i],
                      showSender: widget.isChannel,
                    ),
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
  const _Bubble({required this.message, required this.showSender});

  final Message message;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.outgoing;
    final time = TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(message.sentAt * 1000),
    ).format(context);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSender && !mine && message.senderName != null)
                Text(
                  message.senderName!,
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
                  Text(time, style: Theme.of(context).textTheme.labelSmall),
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
    );
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
