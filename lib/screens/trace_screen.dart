import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/trace.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

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
  const _Done(this.legs);

  final List<TraceLeg> legs;
}

final class _Failed extends _TraceState {
  const _Failed(this.reason);

  final String reason;
}

class _TraceScreenState extends ConsumerState<TraceScreen> {
  _TraceState _state = const _Running();

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
    try {
      final trace = await connection.sync.trace(
        plan.hops,
        hashBytes: plan.hashBytes,
      );
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
      setState(() => _state = _Done(traceLegs(trace, contacts)));
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
        _Done(:final legs) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                context.l10n.signalToNoiseForEachHop,
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final leg in legs)
              ListTile(
                leading: Icon(
                  leg.snr >= 0
                      ? Icons.signal_cellular_alt
                      : leg.snr >= -10
                      ? Icons.signal_cellular_alt_2_bar
                      : Icons.signal_cellular_alt_1_bar,
                ),
                title: Text('${leg.from} → ${leg.to}'),
                trailing: Text(context.l10n.db2(leg.snr.toStringAsFixed(1))),
              ),
          ],
        ),
      },
    );
  }
}
