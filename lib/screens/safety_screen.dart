import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'field_log_screen.dart';
import 'trip_brief_screen.dart';
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

  Future<void> _startSos(String who) => _run(
    () => ref.read(safetyProvider.notifier).sendSos(),
    'SOS sent to $who. It repeats every '
    '${ref.read(sosRepeatProvider).inMinutes} minutes until someone answers.',
  );

  Future<void> _endSos({required bool allClear}) async {
    if (!allClear) {
      final stop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stop the SOS without an all-clear?'),
          content: const Text(
            'It stops repeating, but nobody is told you are safe.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it going'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Stop'),
            ),
          ],
        ),
      );
      if (stop != true || !mounted) return;
    }
    await _run(
      () => ref.read(safetyProvider.notifier).endSos(allClear: allClear),
      allClear ? 'All-clear sent. SOS over.' : 'SOS stopped.',
    );
  }

  /// "#trail", "#trail and 2 trip contacts", "1 trip contact".
  static String _who(String? main, int trip) {
    final people = trip == 0
        ? null
        : '$trip trip contact${trip == 1 ? '' : 's'}';
    if (main == null) return people ?? 'nobody';
    return people == null ? main : '$main and $people';
  }

  Future<void> _pickTripContact(List<Contact> choices) async {
    final notifier = ref.read(safetyProvider.notifier);
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add a trip contact'),
        children: [
          if (choices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No other people in your contacts.'),
            ),
          for (final c in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c.publicKey),
              child: Text(c.name),
            ),
        ],
      ),
    );
    if (picked != null) await notifier.addTripContact(picked);
  }

  String _time(DateTime t) {
    final day = MaterialLocalizations.of(context).formatShortDate(t);
    return '$day ${TimeOfDay.fromDateTime(t).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    String nameOf(String thread) =>
        targets[thread] ?? 'Unknown ${thread.substring(2, 8)}';
    final recipients = safety.recipients
        .where((t) => t != safety.target || target != null)
        .toList();
    final trip = safety.tripContacts;
    final who = _who(target == null ? null : targets[target], trip.length);
    final canSend = connected && recipients.isNotEmpty && !_busy;
    final notifier = ref.read(safetyProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String?>(
            initialValue: target,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Main chat',
              helperText: 'A channel your group watches, or one person.',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
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
            onChanged: notifier.setTarget,
          ),
          const SizedBox(height: 16),
          Text('Trip contacts', style: theme.textTheme.titleSmall),
          Text(
            'Up to $maxTripContacts people who also get every check-in and '
            'SOS, each as a direct message, so you can see who it reached.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final key in trip)
                InputChip(
                  avatar: const Icon(Icons.person, size: 18),
                  label: Text(nameOf(Threads.direct(key))),
                  deleteButtonTooltipMessage:
                      'Remove ${nameOf(Threads.direct(key))}',
                  onDeleted: () => notifier.removeTripContact(key),
                ),
              if (trip.length < maxTripContacts)
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Add trip contact'),
                  onPressed: () => _pickTripContact(
                    contacts.where((c) => !trip.contains(c.publicKey)).toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (safety.sosActive)
            _SosActiveCard(
              safety: safety,
              repeat: ref.watch(sosRepeatProvider),
              time: _time,
              busy: _busy,
              canSend: canSend,
              onSendAgain: () => _run(notifier.sendSos, 'SOS sent again.'),
              onSafe: () => _endSos(allClear: true),
              onStop: () => _endSos(allClear: false),
            )
          else
            HoldToSendButton(
              label: 'Hold for SOS',
              enabled: canSend,
              onSend: () => _startSos(who),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: FilledButton.tonalIcon(
              onPressed: canSend
                  ? () =>
                        _run(notifier.checkIn, "Check-in sent to $who: I'm OK.")
                  : null,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(CheckInKind.ok.label),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, kind) in CheckInKind.values.skip(1).indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: canSend
                        ? () => _run(
                            () => notifier.checkIn(kind),
                            'Check-in sent to $who: ${kind.label}.',
                          )
                        : null,
                    child: Text(kind.label, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !connected
                ? 'Connect a radio to send.'
                : recipients.isEmpty
                ? 'Choose a main chat or a trip contact first.'
                : 'Everything goes to $who, with your position from the '
                      'phone or else the radio. An SOS repeats every '
                      '${ref.watch(sosRepeatProvider).inMinutes} minutes until '
                      'someone answers: any direct reply, or on a channel a '
                      'message that mentions you or says SOS.',
            style: theme.textTheme.bodySmall,
          ),
          if (safety.lastRecord case final record?)
            _CheckInReport(
              record: record,
              nameOf: nameOf,
              time: _time,
              canResend: canSend,
              onResend: (missed) => _run(
                () => notifier.resendCheckIn(missed),
                'Sent again to ${missed.length}.',
              ),
            )
          else if (safety.lastCheckIn case final last?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Last check-in: ${_time(last)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (trip.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<Duration?>(
              initialValue: safety.quietLimit,
              decoration: const InputDecoration(
                labelText: 'Warn me if a trip contact is quiet for',
                helperText:
                    'Nothing from them (a check-in or any message) for '
                    'this long.',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Never')),
                for (final d in quietChoices)
                  DropdownMenuItem(value: d, child: Text(_every(d))),
              ],
              onChanged: notifier.setQuietLimit,
            ),
          ],
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.map_outlined),
            title: const Text('Trip brief'),
            subtitle: const Text('Tell your people where you’re going'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TripBriefScreen()),
            ),
          ),
          if (ref.watch(radioKeyProvider) case final radioKey?)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.article_outlined),
              title: const Text('Field Log'),
              subtitle: const Text('Everything sent and received'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FieldLogScreen(radioKey: radioKey),
                ),
              ),
            ),
          const SizedBox(height: 16),
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
            onChanged: recipients.isEmpty
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
            title: Text(
              'Tell ${recipients.isEmpty ? 'the chat' : who} if I miss one',
            ),
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

/// A big red button that sends only after being held for [hold], so a
/// pocket or a stray tap can't call for help. Screen readers can trigger
/// it with their long-press action.
class HoldToSendButton extends StatefulWidget {
  const HoldToSendButton({
    required this.label,
    required this.onSend,
    this.enabled = true,
    this.hold = const Duration(seconds: 2),
    super.key,
  });

  final String label;
  final VoidCallback onSend;
  final bool enabled;
  final Duration hold;

  @override
  State<HoldToSendButton> createState() => _HoldToSendButtonState();
}

class _HoldToSendButtonState extends State<HoldToSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.hold,
  )..addStatusListener(_done);

  void _done(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _progress.reset();
      widget.onSend();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _hint() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Keep holding for ${widget.hold.inSeconds} seconds to send.',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.enabled;
    final background = enabled
        ? scheme.error
        : scheme.onSurface.withValues(alpha: 0.12);
    final foreground = enabled
        ? scheme.onError
        : scheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      hint: 'Hold for ${widget.hold.inSeconds} seconds',
      onLongPress: enabled ? widget.onSend : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? _hint : null,
        onLongPressDown: enabled ? (_) => _progress.forward() : null,
        onLongPressCancel: () => _progress.reverse(),
        onLongPressUp: () {
          if (_progress.status != AnimationStatus.completed) {
            _progress.reverse();
          }
        },
        // A long press is recognised well before [hold]; the controller
        // decides when it sends.
        onLongPress: enabled ? () {} : null,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => Container(
            height: 72,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(36),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: _progress.value,
                    child: ColoredBox(
                      color: scheme.onError.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sos, size: 32, color: foreground),
                    const SizedBox(width: 8),
                    Text(
                      _progress.value > 0 ? 'Keep holding…' : widget.label,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the SOS button while an SOS is going on.
class _SosActiveCard extends StatelessWidget {
  const _SosActiveCard({
    required this.safety,
    required this.repeat,
    required this.time,
    required this.busy,
    required this.canSend,
    required this.onSendAgain,
    required this.onSafe,
    required this.onStop,
  });

  final SafetyState safety;
  final Duration repeat;
  final String Function(DateTime) time;
  final bool busy;
  final bool canSend;
  final VoidCallback onSendAgain;
  final VoidCallback onSafe;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answered = safety.sosAnsweredBy;
    final last = safety.sosLastSent;
    final sends = safety.sosSends;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sos, color: scheme.onErrorContainer, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SOS active',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: TextStyle(color: scheme.onErrorContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Since ${time(safety.sosSince!)}'),
                  Text(
                    'Sent $sends time${sends == 1 ? '' : 's'}'
                    '${last == null ? '' : ', last at ${time(last)}'}',
                  ),
                  if (answered != null)
                    Text(
                      'Answered by $answered. It no longer repeats.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )
                  else if (last != null)
                    Text(
                      'Next repeat ${time(last.add(repeat))}, unless '
                      'someone answers.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canSend ? onSafe : null,
              icon: const Icon(Icons.check_circle),
              label: const Text("I'm safe"),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canSend ? onSendAgain : null,
                    child: const Text('Send again now'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onStop,
                    child: const Text('Stop without all-clear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A red bar across the home screen while an SOS is going on, so it can't
/// be forgotten. Tapping it opens the Safety screen.
class SosBanner extends ConsumerWidget {
  const SosBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(safetyProvider).value;
    if (s == null || !s.sosActive) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final answered = s.sosAnsweredBy;
    return Material(
      color: scheme.error,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SafetyScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(Icons.sos, color: scheme.onError),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  answered == null
                      ? 'SOS active, repeating. Tap to send I\'m safe.'
                      : 'SOS answered by $answered. Tap to send I\'m safe.',
                  style: TextStyle(color: scheme.onError),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onError),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who the latest check-in reached, with a resend for the ones it missed.
class _CheckInReport extends ConsumerWidget {
  const _CheckInReport({
    required this.record,
    required this.nameOf,
    required this.time,
    required this.canResend,
    required this.onResend,
  });

  final CheckInRecord record;
  final String Function(String thread) nameOf;
  final String Function(DateTime) time;
  final bool canResend;
  final void Function(Set<String> missed) onResend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ids = [for (final s in record.sends) ?s.messageId];
    final messages =
        ref.watch(checkInMessagesProvider(ids.join(','))).value ??
        const <Message>[];
    final byId = {for (final m in messages) m.id: m};
    final missed = <String>{};
    final rows = <Widget>[];
    for (final send in record.sends) {
      final m = send.messageId == null ? null : byId[send.messageId];
      final channel = send.thread.startsWith('c:');
      final (icon, status) = switch (m?.status) {
        _ when send.messageId == null => (Icons.error_outline, 'Not sent'),
        MessageStatus.delivered => (Icons.done_all, 'Reached'),
        MessageStatus.sent when channel => (
          Icons.check,
          'Sent (channels don’t confirm)',
        ),
        MessageStatus.sent => (Icons.check, 'Sent, not confirmed yet'),
        MessageStatus.pending => (Icons.schedule, 'Sending'),
        MessageStatus.failed => (Icons.error_outline, 'Didn’t reach them'),
        _ => (Icons.schedule, 'Sending'),
      };
      if (send.messageId == null || m?.status == MessageStatus.failed) {
        missed.add(send.thread);
      }
      final name = nameOf(send.thread);
      rows.add(
        Semantics(
          label: '$name: $status',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: icon == Icons.error_outline
                      ? theme.colorScheme.error
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(name)),
                Text(status, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      // Each recipient reads as its own line to a screen reader.
      semanticContainer: false,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Last check-in: ${record.kind.label}, ${time(record.at)}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            ...rows,
            if (missed.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: canResend ? () => onResend(missed) : null,
                  icon: const Icon(Icons.refresh),
                  label: Text('Send again to ${missed.length} missed'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
