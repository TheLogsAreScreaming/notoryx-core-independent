import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/node_journal.dart';
import '../app/safety.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';
import 'node_mark_view.dart';

/// Every node this radio has heard, newest first, with behaviour labels.
/// Filter by label or tag, search by name.
class NodeJournalScreen extends ConsumerStatefulWidget {
  const NodeJournalScreen({super.key});

  @override
  ConsumerState<NodeJournalScreen> createState() => _NodeJournalScreenState();
}

class _NodeJournalScreenState extends ConsumerState<NodeJournalScreen> {
  String _query = '';
  NodeBehaviour? _behaviour;
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final radioKey = ref.watch(radioKeyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nodeJournal)),
      body: radioKey == null
          ? Center(child: Text(l10n.journalNoRadio))
          : _body(context, radioKey),
    );
  }

  Widget _body(BuildContext context, String radioKey) {
    final l10n = context.l10n;
    final summaries = ref.watch(journalSummariesProvider(radioKey));
    final all = summaries.value;
    if (all == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final tags = {for (final s in all) ...tagsOf(s.node)}.toList()..sort();
    final query = _query.toLowerCase();
    final shown = [
      for (final s in all)
        if ((query.isEmpty ||
                s.node.name.toLowerCase().contains(query) ||
                s.node.nodeKey.startsWith(query) ||
                s.node.note.toLowerCase().contains(query)) &&
            (_behaviour == null ||
                s.labels.any((l) => l.behaviour == _behaviour)) &&
            (_tag == null || tagsOf(s.node).contains(_tag)))
          s,
    ];
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.journalIntro(all.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: l10n.journalSearch,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final b in NodeBehaviour.values)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: FilterChip(
                    avatar: Icon(behaviourIcon(b), size: 18),
                    label: Text(behaviourName(l10n, b)),
                    selected: _behaviour == b,
                    onSelected: (on) =>
                        setState(() => _behaviour = on ? b : null),
                  ),
                ),
              for (final t in tags)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: FilterChip(
                    avatar: const Icon(Icons.sell_outlined, size: 18),
                    label: Text(t),
                    selected: _tag == t,
                    onSelected: (on) => setState(() => _tag = on ? t : null),
                  ),
                ),
            ],
          ),
        ),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.journalEmpty, textAlign: TextAlign.center),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.journalNoMatches, textAlign: TextAlign.center),
          ),
        for (final s in shown)
          ListTile(
            leading: NodeMarkView(publicKey: s.node.nodeKey),
            title: Text(s.node.name),
            subtitle: Text(
              [
                if (s.labels.isNotEmpty)
                  behaviourName(l10n, s.labels.first.behaviour),
                l10n.journalLastHeard(
                  _ago(
                    context,
                    s.node.lastHeard,
                    ref.read(safetyClockProvider),
                  ),
                ),
                ...tagsOf(s.node),
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => JournalNodeScreen(
                  radioKey: radioKey,
                  nodeKey: s.node.nodeKey,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One node's journal page: its mark, labels with confidence and
/// evidence, the user's tags and note, and its hearing history.
class JournalNodeScreen extends ConsumerStatefulWidget {
  const JournalNodeScreen({
    required this.radioKey,
    required this.nodeKey,
    super.key,
  });

  final String radioKey;
  final String nodeKey;

  @override
  ConsumerState<JournalNodeScreen> createState() => _JournalNodeScreenState();
}

class _JournalNodeScreenState extends ConsumerState<JournalNodeScreen> {
  final _note = TextEditingController();
  bool _noteLoaded = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summaries = ref.watch(journalSummariesProvider(widget.radioKey));
    final summary = summaries.value
        ?.where((s) => s.node.nodeKey == widget.nodeKey)
        .firstOrNull;
    final sightings =
        ref
            .watch(
              journalSightingsProvider((
                radioKey: widget.radioKey,
                nodeKey: widget.nodeKey,
              )),
            )
            .value ??
        const <JournalSighting>[];
    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.nodeJournal)),
        body: Center(
          child: summaries.isLoading
              ? const CircularProgressIndicator()
              : Text(l10n.journalNodeGone),
        ),
      );
    }
    final node = summary.node;
    if (!_noteLoaded) {
      _note.text = node.note;
      _noteLoaded = true;
    }
    final theme = Theme.of(context);
    final now = ref.read(safetyClockProvider)();
    final snrs = [
      for (final s in sightings)
        if (s.snr != null) s.snr!,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(node.name),
        actions: [
          IconButton(
            tooltip: l10n.journalForget,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _forget(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              NodeMarkView(publicKey: node.nodeKey, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.name, style: theme.textTheme.titleLarge),
                    Text(_typeName(l10n, node.type)),
                    SelectableText(
                      node.nodeKey.substring(0, 16).toUpperCase(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.journalFirstLast(
              _ago(context, node.firstHeard, () => now),
              _ago(context, node.lastHeard, () => now),
              node.heardCount,
            ),
          ),
          if (snrs.isNotEmpty)
            Text(
              l10n.journalSnrRange(
                snrs.reduce((a, b) => a < b ? a : b).toStringAsFixed(1),
                snrs.reduce((a, b) => a > b ? a : b).toStringAsFixed(1),
                snrs.last.toStringAsFixed(1),
              ),
            ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(l10n.journalLabels, style: theme.textTheme.titleMedium),
          ),
          if (summary.labels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.journalNoLabels),
            ),
          for (final label in summary.labels) _LabelCard(label: label),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(l10n.journalTags, style: theme.textTheme.titleMedium),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final t in tagsOf(node))
                InputChip(
                  label: Text(t),
                  deleteButtonTooltipMessage: l10n.journalRemoveTag(t),
                  onDeleted: () => saveJournalNotes(
                    ref.read(databaseProvider),
                    widget.radioKey,
                    node.nodeKey,
                    tags: tagsOf(node).where((x) => x != t).toList(),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l10n.journalAddTag),
                onPressed: () => _addTag(context, node),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.journalNote,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => saveJournalNotes(
              ref.read(databaseProvider),
              widget.radioKey,
              node.nodeKey,
              note: v,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTag(BuildContext context, JournalNode node) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.journalAddTag),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: InputDecoration(labelText: l10n.journalTag),
          onSubmitted: (v) => Navigator.pop(dialog, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: Text(l10n.journalAddTag),
          ),
        ],
      ),
    );
    controller.dispose();
    if (tag == null || tag.trim().isEmpty) return;
    await saveJournalNotes(
      ref.read(databaseProvider),
      widget.radioKey,
      node.nodeKey,
      tags: [...tagsOf(node), tag],
    );
  }

  Future<void> _forget(BuildContext context) async {
    final l10n = context.l10n;
    final db = ref.read(databaseProvider);
    final navigator = Navigator.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.journalForgetTitle),
        content: Text(l10n.journalForgetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.journalForget),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await forgetJournalNode(db, widget.radioKey, widget.nodeKey);
    if (mounted) navigator.pop();
  }
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({required this.label});

  final NodeLabel label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final percent = (label.confidence * 100).round();
    final name = behaviourName(l10n, label.behaviour);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
                children: [
                  Icon(behaviourIcon(label.behaviour)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(l10n.journalConfidence(percent)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // The row above says how sure, in words; the bar repeats it.
            ExcludeSemantics(
              child: LinearProgressIndicator(value: label.confidence),
            ),
            const SizedBox(height: 6),
            for (final e in label.evidence) Text('• ${evidenceText(l10n, e)}'),
          ],
        ),
      ),
    );
  }
}

String behaviourName(AppLocalizations l10n, NodeBehaviour b) => switch (b) {
  NodeBehaviour.alwaysOn => l10n.behaviourAlwaysOn,
  NodeBehaviour.regular => l10n.behaviourRegular,
  NodeBehaviour.roamer => l10n.behaviourRoamer,
  NodeBehaviour.rarelyHeard => l10n.behaviourRarelyHeard,
  NodeBehaviour.newArrival => l10n.behaviourNewArrival,
  NodeBehaviour.goneQuiet => l10n.behaviourGoneQuiet,
};

IconData behaviourIcon(NodeBehaviour b) => switch (b) {
  NodeBehaviour.alwaysOn => Icons.cell_tower,
  NodeBehaviour.regular => Icons.event_repeat,
  NodeBehaviour.roamer => Icons.directions_walk,
  NodeBehaviour.rarelyHeard => Icons.hourglass_empty,
  NodeBehaviour.newArrival => Icons.fiber_new_outlined,
  NodeBehaviour.goneQuiet => Icons.volume_off_outlined,
};

String evidenceText(AppLocalizations l10n, Evidence e) => switch (e) {
  HeardOnDays(:final days, :final window) => l10n.evidenceHeardOnDays(
    days,
    window,
  ),
  TypicalGap(:final hours) => l10n.evidenceTypicalGap(hours.toStringAsFixed(1)),
  IsInfrastructure() => l10n.evidenceInfrastructure,
  PositionSpread(:final km, :final places) => l10n.evidencePositionSpread(
    km.toStringAsFixed(1),
    places,
  ),
  HeardTimes(:final times, :final days) => l10n.evidenceHeardTimes(times, days),
  FirstHeardAgo(:final hours) => l10n.evidenceFirstHeard(hours),
  LastHeardAgo(:final days) => l10n.evidenceLastHeard(days),
};

String _typeName(AppLocalizations l10n, int type) =>
    switch (NodeType.fromByte(type)) {
      NodeType.repeater => l10n.journalTypeRepeater,
      NodeType.room => l10n.journalTypeRoom,
      NodeType.sensor => l10n.journalTypeSensor,
      _ => l10n.journalTypeCompanion,
    };

String _ago(BuildContext context, int ms, DateTime Function() clock) {
  final l10n = context.l10n;
  final d = clock().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return l10n.agoJustNow;
  if (d.inHours < 1) return l10n.agoMinutes(d.inMinutes);
  if (d.inDays < 1) return l10n.agoHours(d.inHours);
  return l10n.agoDays(d.inDays);
}
