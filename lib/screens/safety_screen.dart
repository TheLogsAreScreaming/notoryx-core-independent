import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/safety.dart';
import '../data/data.dart';
import '../radio/radio.dart';

/// SOS, "I'm OK" check-ins, and the check-in timer.
class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on SafetyException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on RadioRequestException {
      messenger.showSnackBar(
        const SnackBar(content: Text('The radio could not send it.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSos(String targetName) async {
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos),
        title: const Text('Send SOS?'),
        content: Text(
          'A call for help with your position goes to $targetName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;
    await _run(
      () => ref.read(safetyProvider.notifier).sendSos(),
      'SOS sent to $targetName.',
    );
  }

  String _time(DateTime t) {
    final day = MaterialLocalizations.of(context).formatShortDate(t);
    return '$day ${TimeOfDay.fromDateTime(t).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radioKey = ref.watch(radioKeyProvider);
    final connected = ref.watch(connectionProvider) is Connected;
    final safety = ref.watch(safetyProvider).value ?? const SafetyState();
    final channels = radioKey == null
        ? const <Channel>[]
        : ref.watch(channelsProvider(radioKey)).value ?? const <Channel>[];
    final contacts = radioKey == null
        ? const <Contact>[]
        : (ref.watch(contactsProvider(radioKey)).value ?? const <Contact>[])
              .where((c) => c.type == NodeType.chat.value)
              .toList();
    final targets = <String, String>{
      for (final c in channels) Threads.channel(c.slot): c.name,
      for (final c in contacts) Threads.direct(c.publicKey): c.name,
    };
    final target = targets.containsKey(safety.target) ? safety.target : null;
    final targetName = target == null ? null : targets[target];
    final canSend = connected && target != null && !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: target,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Send to',
              helperText: 'A channel your group watches, or one person.',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final MapEntry(:key, :value) in targets.entries)
                DropdownMenuItem(
                  value: key,
                  child: Row(
                    children: [
                      Icon(
                        key.startsWith('c:') ? Icons.tag : Icons.person,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(value)),
                    ],
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) ref.read(safetyProvider.notifier).setTarget(v);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 72,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                textStyle: theme.textTheme.titleLarge,
              ),
              onPressed: canSend ? () => _confirmSos(targetName!) : null,
              icon: const Icon(Icons.sos, size: 32),
              label: const Text('Send SOS'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton.tonalIcon(
              onPressed: canSend
                  ? () => _run(
                      () => ref.read(safetyProvider.notifier).checkIn(),
                      'Check-in sent to $targetName.',
                    )
                  : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("I'm OK"),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            !connected
                ? 'Connect a radio to send.'
                : target == null
                ? 'Choose where to send first.'
                : 'Both include your position, from the phone or else '
                      'the radio.',
            style: theme.textTheme.bodySmall,
          ),
          if (safety.lastCheckIn case final last?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Last check-in: ${_time(last)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const Divider(height: 40),
          Text('Check-in timer', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Going somewhere alone? Set how often you’ll check in. When one '
            'is due the phone reminds you, and if you don’t answer, your '
            'chat is told where you were last.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Duration?>(
            initialValue: safety.timerOn ? safety.every : null,
            decoration: const InputDecoration(
              labelText: 'Check in every',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Off')),
              for (final d in checkInChoices)
                DropdownMenuItem(value: d, child: Text(_every(d))),
            ],
            onChanged: target == null
                ? null
                : (d) {
                    final safety = ref.read(safetyProvider.notifier);
                    if (d == null) {
                      safety.stopTimer();
                    } else {
                      safety.startTimer(d);
                    }
                  },
          ),
          if (safety.due case final due? when safety.timerOn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Next check-in due ${_time(due)}',
                style: theme.textTheme.titleSmall,
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Tell ${targetName ?? 'the chat'} if I miss one'),
            subtitle: Text(
              '${ref.watch(checkInGraceProvider).inMinutes} minutes after '
              'the reminder. Needs the radio connected.',
            ),
            value: safety.alertOnMiss,
            onChanged: (v) =>
                ref.read(safetyProvider.notifier).setAlertOnMiss(v),
          ),
        ],
      ),
    );
  }

  static String _every(Duration d) => d.inMinutes < 60
      ? '${d.inMinutes} minutes'
      : d.inHours == 1
      ? '1 hour'
      : '${d.inHours} hours';
}
