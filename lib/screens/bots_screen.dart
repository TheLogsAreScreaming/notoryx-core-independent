import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/bots.dart';
import '../data/data.dart';

/// Turns automatic replies on and off, and edits their rules.
class BotsScreen extends ConsumerWidget {
  const BotsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final rule = await showDialog<_NewRule>(
      context: context,
      builder: (_) => const _RuleDialog(),
    );
    if (rule == null) return;
    await ref
        .read(botsProvider.notifier)
        .addRule(
          trigger: rule.trigger,
          reply: rule.reply,
          onChannels: rule.onChannels,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(botsProvider).value ?? const BotSettings();
    final notifier = ref.read(botsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-replies')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add a rule',
        onPressed: () => _add(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          SwitchListTile(
            title: const Text('Send automatic replies'),
            subtitle: const Text(
              'Only while the app is running and connected.',
            ),
            value: settings.enabled,
            onChanged: notifier.setEnabled,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Every reply uses airtime other people share. Replies are '
              'limited to $botHourlyLimit an hour, wait between repeats, and '
              'never go to blocked senders, old messages, or SOS and '
              'check-in messages.',
            ),
          ),
          if (settings.rules.isEmpty)
            const ListTile(
              title: Text('No rules yet'),
              subtitle: Text('Add one with the + button.'),
            ),
          for (final rule in settings.rules)
            ListTile(
              leading: Icon(
                rule.isAway ? Icons.bedtime_outlined : Icons.smart_toy_outlined,
              ),
              title: Text(
                rule.isAway ? 'Away message' : 'When it says “${rule.trigger}”',
              ),
              subtitle: Text(
                '${rule.reply}\n'
                '${rule.onChannels ? 'Direct messages and channels' : 'Direct messages only'}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Delete rule',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => notifier.removeRule(rule.id),
              ),
            ),
        ],
      ),
    );
  }
}

typedef _NewRule = ({String trigger, String reply, bool onChannels});

class _RuleDialog extends StatefulWidget {
  const _RuleDialog();

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _trigger = TextEditingController();
  final _reply = TextEditingController();
  bool _channels = false;

  @override
  void dispose() {
    _trigger.dispose();
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reply = _reply.text.trim();
    final away = _trigger.text.trim().isEmpty;
    final fits = utf8.encode(reply).length <= maxDirectTextBytes;
    return AlertDialog(
      title: const Text('New rule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _trigger,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'When a message says',
                hintText: 'ping',
                helperText: 'Empty makes an away message for direct chats.',
              ),
            ),
            TextField(
              controller: _reply,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Reply with',
                hintText: 'pong {name}, it is {time}',
                errorText: fits ? null : 'Too long for one message.',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Also on channels'),
              value: _channels && !away,
              onChanged: away
                  ? null
                  : (v) => setState(() => _channels = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: reply.isEmpty || !fits
              ? null
              : () => Navigator.of(context).pop((
                  trigger: _trigger.text,
                  reply: reply,
                  onChannels: _channels,
                )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
