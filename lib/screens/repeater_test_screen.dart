import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/repeater_test.dart';
import '../l10n/l10n.dart';

/// One tap asks the repeaters in range to answer and lists who did, with
/// the signal each way. Starts a test when opened.
class RepeaterTestScreen extends ConsumerStatefulWidget {
  const RepeaterTestScreen({super.key});

  @override
  ConsumerState<RepeaterTestScreen> createState() => _RepeaterTestScreenState();
}

class _RepeaterTestScreenState extends ConsumerState<RepeaterTestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(repeaterTestProvider.notifier).run().ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(repeaterTestProvider);
    final canRun = ref.watch(repeaterProbeProvider) != null;
    final running = state is RepeaterTestRunning;
    final radioKey = ref.watch(radioKeyProvider) ?? '';
    final contacts = ref.watch(contactsProvider(radioKey)).value ?? const [];
    final discovered =
        ref.watch(discoveredProvider(radioKey)).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.nearbyRepeaterTest)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(l10n.nearbyRepeaterTestIntro),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              icon: const Icon(Icons.cell_tower),
              label: Text(
                state is RepeaterTestIdle
                    ? l10n.testForRepeaters
                    : l10n.testAgain,
              ),
              onPressed: canRun && !running
                  ? () => ref.read(repeaterTestProvider.notifier).run()
                  : null,
            ),
          ),
          if (!canRun)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(l10n.connectToTheRadioFirst),
            ),
          const SizedBox(height: 12),
          ...switch (state) {
            RepeaterTestIdle() => const <Widget>[],
            RepeaterTestRunning() => [
              Semantics(
                liveRegion: true,
                child: ListTile(
                  leading: const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text(l10n.listeningForRepeaters),
                ),
              ),
            ],
            RepeaterTestFailed() => [
              Semantics(
                liveRegion: true,
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(l10n.repeaterTestFailed),
                ),
              ),
            ],
            RepeaterTestDone(:final hits, :final at) => [
              Semantics(
                liveRegion: true,
                child: ListTile(
                  title: Text(
                    hits.isEmpty
                        ? l10n.noRepeatersAnswered
                        : l10n.repeatersAnswered(hits.length),
                  ),
                  subtitle: Text(
                    hits.isEmpty
                        ? l10n.noRepeatersAnsweredHint
                        : l10n.testedAt(
                            TimeOfDay.fromDateTime(at).format(context),
                          ),
                  ),
                ),
              ),
              for (final r in responders(
                hits,
                contacts: contacts,
                discovered: discovered,
              ))
                _ResponderTile(responder: r),
            ],
          },
        ],
      ),
    );
  }
}

class _ResponderTile extends StatelessWidget {
  const _ResponderTile({required this.responder});

  final Responder responder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final r = responder;
    final (color, icon, label) = switch (r.signal) {
      ResponderSignal.strong => (
        scheme.primary,
        Icons.signal_cellular_alt,
        l10n.signalStrong,
      ),
      ResponderSignal.usable => (
        scheme.tertiary,
        Icons.signal_cellular_alt_2_bar,
        l10n.signalUsable,
      ),
      ResponderSignal.weak => (
        scheme.error,
        Icons.signal_cellular_alt_1_bar,
        l10n.signalWeak,
      ),
    };
    final name = r.name ?? l10n.unknownRepeater;
    final id = r.publicKey.substring(0, 8).toUpperCase();
    final heardUs = r.heardUs.toStringAsFixed(1);
    final weHeard = r.weHeard.toStringAsFixed(1);
    return Semantics(
      container: true,
      label: l10n.responderSemantics(name, label, heardUs, weHeard, r.rssi),
      child: ExcludeSemantics(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(name),
          subtitle: Text(
            '$label · $id\n'
            '${l10n.heardYouAt(heardUs)} · ${l10n.youHeardItAt(weHeard)} · '
            '${l10n.rssiValue(r.rssi)}',
          ),
          isThreeLine: true,
          trailing: r.isContact ? null : Text(l10n.notAContact),
        ),
      ),
    );
  }
}
