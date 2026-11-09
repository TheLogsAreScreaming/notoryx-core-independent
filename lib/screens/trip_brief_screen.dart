import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/field_log.dart';
import '../app/safety.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

/// Writes down where you're going and sends it to your main chat and trip
/// contacts as one message.
class TripBriefScreen extends ConsumerStatefulWidget {
  const TripBriefScreen({super.key});

  @override
  ConsumerState<TripBriefScreen> createState() => _TripBriefScreenState();
}

class _TripBriefScreenState extends ConsumerState<TripBriefScreen> {
  final _where = TextEditingController();
  final _backBy = TextEditingController();
  final _people = TextEditingController();
  final _notes = TextEditingController();
  bool _sending = false;

  TripBrief get _brief => TripBrief(
    where: _where.text,
    backBy: _backBy.text,
    people: _people.text,
    notes: _notes.text,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(tripBriefSetting);
    if (!mounted) return;
    final saved = TripBrief.fromJson(raw);
    setState(() {
      _where.text = saved.where;
      _backBy.text = saved.backBy;
      _people.text = saved.people;
      _notes.text = saved.notes;
    });
  }

  @override
  void dispose() {
    _where.dispose();
    _backBy.dispose();
    _people.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final brief = _brief;
    setState(() => _sending = true);
    try {
      await ref
          .read(storeProvider)
          .saveSetting(tripBriefSetting, brief.toJson());
      final count = await ref
          .read(safetyProvider.notifier)
          .sendTripBrief(brief.text);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tripBriefSentTo(count))),
      );
    } on SafetyException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotSendIt)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _field(TextEditingController c, String label, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final brief = _brief;
    final length = brief.byteLength;
    final tooLong = length > maxDirectTextBytes;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tripBrief)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_where, 'Going to', 'Trail, area or route'),
          _field(_backBy, 'Back by', 'Sat 6 pm'),
          _field(_people, 'Who’s going', 'Sam, Alex'),
          _field(_notes, 'Notes', 'Car at north lot'),
          if (!brief.isEmpty) ...[
            Text(context.l10n.willSend, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(brief.text),
            const SizedBox(height: 4),
          ],
          Text(
            tooLong
                ? '$length of $maxDirectTextBytes bytes. Too long for one '
                      'message: shorten it to send.'
                : '$length of $maxDirectTextBytes bytes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tooLong ? theme.colorScheme.error : null,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: Text(context.l10n.sendToMainChatAndTrip),
            onPressed: brief.isEmpty || tooLong || _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}
