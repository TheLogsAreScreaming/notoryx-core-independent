import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/safety.dart';
import '../app/scheduled_messages.dart';

/// Offers when to send, and returns the time. Null if cancelled.
Future<DateTime?> pickSendTime(BuildContext context, DateTime now) async {
  final tomorrow = DateTime(now.year, now.month, now.day + 1, 8);
  final choice = await showModalBottomSheet<Object>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, at) in [
            ('In 15 minutes', now.add(const Duration(minutes: 15))),
            ('In 1 hour', now.add(const Duration(hours: 1))),
            ('In 3 hours', now.add(const Duration(hours: 3))),
            ('Tomorrow at 8:00', tomorrow),
          ])
            ListTile(
              title: Text(label),
              onTap: () => Navigator.pop(context, at),
            ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Pick a time'),
            onTap: () => Navigator.pop(context, 'pick'),
          ),
        ],
      ),
    ),
  );
  if (choice is DateTime) return choice;
  if (choice != 'pick' || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now),
  );
  if (time == null) return null;
  final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  // A time already past today means tomorrow.
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
}

String _when(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.month}/${at.day} ${two(at.hour)}:${two(at.minute)}';
}

/// A link to the waiting messages, shown only when there are some.
class ScheduledStrip extends ConsumerWidget {
  const ScheduledStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(scheduledMessagesProvider).value?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      leading: const Icon(Icons.schedule_send),
      title: Text(
        count == 1 ? '1 scheduled message' : '$count scheduled messages',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ScheduledScreen())),
    );
  }
}

/// Lists the waiting messages, and cancels them.
class ScheduledScreen extends ConsumerWidget {
  const ScheduledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(scheduledMessagesProvider).value ?? const [];
    final now = ref.read(safetyClockProvider)();
    final connected = ref.watch(connectionProvider) is Connected;
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled messages')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              connected
                  ? 'These send while the app is running and connected.'
                  : 'No radio connected. These wait until one is.',
            ),
          ),
          for (final m in list)
            ListTile(
              title: Text(m.title),
              subtitle: Text(
                '${m.isMissed(now) ? 'Missed, not sent' : _when(m.at)}\n${m.text}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Cancel this message',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(scheduledMessagesProvider.notifier).remove(m.id),
              ),
            ),
        ],
      ),
    );
  }
}
