import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/contact_room.dart';
import '../data/data.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

/// Pick contacts to remove so the radio has room for new ones. Favourites
/// are never listed; the ones heard longest ago come first.
class ContactCleanupScreen extends ConsumerStatefulWidget {
  const ContactCleanupScreen({required this.radioKey, super.key});

  final String radioKey;

  @override
  ConsumerState<ContactCleanupScreen> createState() =>
      _ContactCleanupScreenState();
}

class _ContactCleanupScreenState extends ConsumerState<ContactCleanupScreen> {
  final _picked = <String>{};
  bool _removing = false;
  int _done = 0;
  int _total = 0;

  Future<void> _remove(List<Contact> picked) async {
    final state = ref.read(connectionProvider);
    if (state is! Connected) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove ${picked.length} contact${picked.length == 1 ? '' : 's'}?',
        ),
        content: Text(context.l10n.theRadioForgetsThemChatsAlready),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _removing = true;
      _done = 0;
      _total = picked.length;
    });
    var failed = 0;
    for (final c in picked) {
      try {
        await state.sync.removeContact(PublicKey.fromHex(c.publicKey));
      } on RadioRequestException {
        failed++;
      }
      if (!mounted) return;
      setState(() {
        _done++;
        _picked.remove(c.publicKey);
      });
    }
    setState(() => _removing = false);
    final removed = picked.length - failed;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Removed $removed.'
              : 'Removed $removed. The radio refused $failed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionProvider);
    final max = state is Connected ? state.radio.device.maxContacts : null;
    final contacts =
        ref.watch(contactsProvider(widget.radioKey)).value ?? const <Contact>[];
    final candidates = removalCandidates(contacts);
    final picked = candidates
        .where((c) => _picked.contains(c.publicKey))
        .toList();
    final now = DateTime.now();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.makeRoomForContacts)),
      body: Column(
        children: [
          if (max != null)
            ContactMeterBar(
              meter: ContactMeter(contacts.length - picked.length, max),
              prefix: picked.isEmpty ? null : 'After removing',
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.heardLongestAgoFirstFavouritesAren,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: candidates.isEmpty || _removing
                      ? null
                      : () => setState(() {
                          _picked
                            ..clear()
                            ..addAll(
                              candidates.take(10).map((c) => c.publicKey),
                            );
                        }),
                  child: Text(context.l10n.pickOldest10),
                ),
              ],
            ),
          ),
          Expanded(
            child: candidates.isEmpty
                ? Center(child: Text(context.l10n.nothingToRemove))
                : ListView(
                    children: [
                      for (final c in candidates)
                        CheckboxListTile(
                          value: _picked.contains(c.publicKey),
                          onChanged: _removing
                              ? null
                              : (on) => setState(
                                  () => on == true
                                      ? _picked.add(c.publicKey)
                                      : _picked.remove(c.publicKey),
                                ),
                          title: Text(c.name),
                          subtitle: Text(
                            '${_kind(c.type)} · ${lastHeard(c.lastAdvert, now)}',
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: picked.isEmpty || _removing || state is! Connected
                      ? null
                      : () => _remove(picked),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: Text(
                    _removing
                        ? 'Removing $_done of $_total…'
                        : picked.isEmpty
                        ? 'Pick contacts to remove'
                        : 'Remove ${picked.length}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _kind(int type) => switch (NodeType.fromByte(type)) {
    NodeType.repeater => 'Repeater',
    NodeType.room => 'Room',
    NodeType.sensor => 'Sensor',
    _ => 'Person',
  };
}

/// "120 of 350 contacts" with a bar; warns when nearly full.
class ContactMeterBar extends StatelessWidget {
  const ContactMeterBar({
    required this.meter,
    this.prefix,
    this.onMakeRoom,
    super.key,
  });

  final ContactMeter meter;

  /// Words before the count, e.g. "After removing".
  final String? prefix;

  /// Shows a "Make room" button when the table is nearly full.
  final VoidCallback? onMakeRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final level = meter.level;
    final warn = level != ContactLevel.ok;
    final count = '${meter.count} of ${meter.max} contacts';
    final note = switch (level) {
      ContactLevel.full => 'Full: the radio won’t add new nodes it hears.',
      ContactLevel.nearlyFull => 'Nearly full: ${meter.free} left.',
      ContactLevel.ok => null,
    };
    return Semantics(
      container: true,
      label: [?prefix, count, ?note].join('. '),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            if (warn)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ExcludeSemantics(
                  child: Icon(Icons.warning_amber, color: scheme.error),
                ),
              ),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prefix == null ? count : '$prefix: $count',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: meter.fraction,
                      color: warn ? scheme.error : null,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(note, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
            ),
            if (warn && onMakeRoom != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton(
                  onPressed: onMakeRoom,
                  child: Text(context.l10n.makeRoom),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
