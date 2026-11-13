import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/trace.dart';
import '../app/trace_card.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';
import 'trace_card_view.dart';

/// Saves a trace card picture. Returns whether it was saved. Tests replace
/// this.
final traceCardSaverProvider =
    Provider<Future<bool> Function(String name, Uint8List bytes)>(
      (ref) =>
          (name, bytes) async =>
              await FilePicker.saveFile(
                fileName: name,
                bytes: bytes,
                dialogTitle: 'Save trace card',
              ) !=
              null,
    );

/// Sends a trace along the route to [contact] and back, then shows how
/// well each hop heard the one before.
class TraceScreen extends ConsumerStatefulWidget {
  const TraceScreen({required this.contact, super.key});

  final Contact contact;

  @override
  ConsumerState<TraceScreen> createState() => _TraceScreenState();
}

sealed class _TraceState {
  const _TraceState();
}

final class _Running extends _TraceState {
  const _Running();
}

final class _Done extends _TraceState {
  const _Done(this.card);

  final TraceCard card;
}

final class _Failed extends _TraceState {
  const _Failed(this.reason);

  final String reason;
}

class _TraceScreenState extends ConsumerState<TraceScreen> {
  _TraceState _state = const _Running();
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final connection = ref.read(connectionProvider);
    final plan = planTrace(widget.contact);
    if (connection is! Connected) {
      setState(() => _state = const _Failed('Connect to the radio first.'));
      return;
    }
    if (plan == null) {
      setState(
        () => _state = const _Failed(
          'There’s no route through repeaters to trace yet.',
        ),
      );
      return;
    }
    setState(() => _state = const _Running());
    final sentAt = DateTime.now();
    try {
      final trace = await connection.sync.trace(
        plan.hops,
        hashBytes: plan.hashBytes,
      );
      final returnedAt = DateTime.now();
      if (!mounted) return;
      if (trace == null) {
        setState(
          () => _state = const _Failed(
            'The trace didn’t come back. A hop on the route may be out '
            'of reach or switched off.',
          ),
        );
        return;
      }
      final contacts = await ref
          .read(storeProvider)
          .watchContacts(connection.radio.key)
          .first;
      if (!mounted) return;
      final self = connection.radio.self;
      setState(
        () => _state = _Done(
          TraceCard.fromTrace(
            trace: trace,
            contacts: contacts,
            senderName: self.name,
            targetName: widget.contact.name,
            sentAt: sentAt,
            returnedAt: returnedAt,
            selfLatitude: self.latitude,
            selfLongitude: self.longitude,
          ),
        ),
      );
    } on RadioRequestException {
      if (mounted) {
        setState(
          () => _state = const _Failed('The radio could not send the trace.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.traceTo(widget.contact.name)),
        actions: [
          if (_state case _Done(:final card)) ...[
            IconButton(
              tooltip: context.l10n.traceCardCopyText,
              icon: const Icon(Icons.copy_all),
              onPressed: () => _copyText(card),
            ),
            IconButton(
              tooltip: context.l10n.traceCardSavePicture,
              icon: const Icon(Icons.image_outlined),
              onPressed: _savePicture,
            ),
          ],
          IconButton(
            tooltip: context.l10n.traceAgain,
            icon: const Icon(Icons.refresh),
            onPressed: _state is _Running ? null : _run,
          ),
        ],
      ),
      body: switch (_state) {
        _Running() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(context.l10n.tracingTheRoute),
            ],
          ),
        ),
        _Failed(:final reason) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(reason, textAlign: TextAlign.center),
          ),
        ),
        _Done(:final card) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                context.l10n.signalToNoiseForEachHop,
                style: theme.textTheme.bodySmall,
              ),
            ),
            TraceCardView(card: card, boundaryKey: _cardKey),
          ],
        ),
      },
    );
  }

  Future<void> _copyText(TraceCard card) async {
    final text = card.toText(context.l10n);
    final done = context.l10n.traceCardCopied;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  Future<void> _savePicture() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final save = ref.read(traceCardSaverProvider);
    final bytes = await traceCardPng(_cardKey);
    if (bytes == null) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final saved = await save('trace-$stamp.png', bytes);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(saved ? l10n.traceCardSaved : l10n.traceCardNotSaved),
      ),
    );
  }
}
