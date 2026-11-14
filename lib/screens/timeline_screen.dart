import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/safety.dart';
import '../app/timeline.dart';
import '../l10n/l10n.dart';
import 'conversation_screen.dart';
import 'node_journal_screen.dart';
import 'node_mark_view.dart';
import 'position_map_screen.dart';

/// How far back the timeline looks.
enum TimelineRange {
  day(Duration(days: 1)),
  week(Duration(days: 7)),
  month(Duration(days: 30));

  const TimelineRange(this.span);

  final Duration span;
}

/// One filterable feed of messages, nodes heard for the first time, signal
/// changes and positions.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  TimelineRange _range = TimelineRange.week;
  final Set<TimelineKind> _kinds = {...TimelineKind.values};
  String _query = '';
  Future<List<TimelineEvent>>? _events;
  String? _loadedFor;

  Future<List<TimelineEvent>> _load(String radioKey) => loadTimeline(
    ref.read(storeProvider),
    ref.read(databaseProvider),
    radioKey,
    ref.read(safetyClockProvider)().subtract(_range.span),
  );

  void _reload(String radioKey) => setState(() {
    _events = _load(radioKey);
    _loadedFor = radioKey;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final radioKey = ref.watch(radioKeyProvider);
    if (radioKey != null && radioKey != _loadedFor) {
      _events = _load(radioKey);
      _loadedFor = radioKey;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.timeline),
        actions: [
          if (radioKey != null)
            IconButton(
              tooltip: l10n.timelineRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => _reload(radioKey),
            ),
        ],
      ),
      body: radioKey == null
          ? Center(child: Text(l10n.journalNoRadio))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SegmentedButton<TimelineRange>(
                    segments: [
                      ButtonSegment(
                        value: TimelineRange.day,
                        label: Text(l10n.timelineDay),
                      ),
                      ButtonSegment(
                        value: TimelineRange.week,
                        label: Text(l10n.timelineWeek),
                      ),
                      ButtonSegment(
                        value: TimelineRange.month,
                        label: Text(l10n.timelineMonth),
                      ),
                    ],
                    selected: {_range},
                    onSelectionChanged: (s) {
                      _range = s.single;
                      _reload(radioKey);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: l10n.timelineSearch,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final k in TimelineKind.values)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: FilterChip(
                            avatar: Icon(_icon(k), size: 18),
                            label: Text(_kindName(l10n, k)),
                            selected: _kinds.contains(k),
                            onSelected: (on) => setState(
                              () => on ? _kinds.add(k) : _kinds.remove(k),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<TimelineEvent>>(
                    future: _events,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(child: Text(l10n.timelineError));
                      }
                      final all = snap.data;
                      if (all == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final shown = filterTimeline(all, _kinds, query: _query);
                      if (shown.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              all.isEmpty
                                  ? l10n.timelineEmpty
                                  : l10n.timelineNoMatches,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, i) =>
                            _EventTile(event: shown[i], radioKey: radioKey),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

IconData _icon(TimelineKind k) => switch (k) {
  TimelineKind.message => Icons.chat_bubble_outline,
  TimelineKind.newNode => Icons.fiber_new_outlined,
  TimelineKind.signal => Icons.network_check,
  TimelineKind.position => Icons.place_outlined,
};

String _kindName(AppLocalizations l10n, TimelineKind k) => switch (k) {
  TimelineKind.message => l10n.timelineMessages,
  TimelineKind.newNode => l10n.timelineNewNodes,
  TimelineKind.signal => l10n.timelineSignal,
  TimelineKind.position => l10n.timelinePositions,
};

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.radioKey});

  final TimelineEvent event;
  final String radioKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(event.at));
    final day = MaterialLocalizations.of(context).formatShortDate(event.at);
    final when = '$day $time';
    final (
      Widget leading,
      String title,
      String subtitle,
      VoidCallback tap,
    ) = switch (event) {
      MessageEvent(
        :final chat,
        :final thread,
        :final body,
        :final outgoing,
        :final sender,
      ) =>
        (
          Icon(outgoing ? Icons.north_east : Icons.south_west),
          outgoing
              ? l10n.timelineYouSent(chat)
              : l10n.timelineReceived(sender ?? chat, chat),
          body,
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ConversationScreen(
                thread: thread,
                title: chat,
                isChannel: thread.startsWith('c:'),
              ),
            ),
          ),
        ),
      NewNodeEvent(:final name, :final nodeKey) => (
        NodeMarkView(publicKey: nodeKey),
        l10n.timelineFirstHeard(name),
        l10n.timelineNewNodeHint,
        () => _openNode(context, nodeKey),
      ),
      SignalEvent(:final name, :final nodeKey, :final from, :final to) => (
        Icon(to > from ? Icons.trending_up : Icons.trending_down),
        to > from ? l10n.timelineSignalUp(name) : l10n.timelineSignalDown(name),
        l10n.timelineSignalDetail(
          from.toStringAsFixed(1),
          to.toStringAsFixed(1),
        ),
        () => _openNode(context, nodeKey),
      ),
      PositionEvent(
        :final name,
        :final position,
        :final chat,
        :final nodeKey,
      ) =>
        (
          const Icon(Icons.place_outlined),
          chat != null
              ? l10n.timelineSharedPosition(
                  name.isEmpty ? l10n.timelineYou : name,
                  chat,
                )
              : l10n.timelineNewPlace(name),
          '${position.latitude.toStringAsFixed(5)}, '
              '${position.longitude.toStringAsFixed(5)}',
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PositionMapScreen(
                position: position,
                label: name.isEmpty ? l10n.timelineYou : name,
              ),
            ),
          ),
        ),
    };
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(
        '$subtitle\n$when',
        maxLines: 4,
        overflow: TextOverflow.fade,
      ),
      isThreeLine: true,
      onTap: tap,
    );
  }

  void _openNode(BuildContext context, String nodeKey) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              JournalNodeScreen(radioKey: radioKey, nodeKey: nodeKey),
        ),
      );
}
