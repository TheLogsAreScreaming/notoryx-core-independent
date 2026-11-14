/// The timeline: one feed of what happened on the mesh, newest first:
/// messages, nodes heard for the first time, big signal changes and
/// shared or advertised positions. Built from what the app already keeps
/// (messages and the node journal), so it needs no storage of its own.
library;

import 'package:latlong2/latlong.dart';

import '../data/data.dart';
import 'node_journal.dart' show sightingsSince;
import 'notifications.dart' show chatLinkFor;
import 'shared_items.dart' show sharedPosition;

/// What kind of entry, for filtering.
enum TimelineKind { message, newNode, signal, position }

sealed class TimelineEvent {
  const TimelineEvent(this.at);

  final DateTime at;

  TimelineKind get kind;
}

/// A message sent or received in [chat].
final class MessageEvent extends TimelineEvent {
  const MessageEvent(
    super.at, {
    required this.chat,
    required this.thread,
    required this.body,
    required this.outgoing,
    this.sender,
  });

  final String chat;
  final String thread;
  final String body;
  final bool outgoing;
  final String? sender;

  @override
  TimelineKind get kind => TimelineKind.message;
}

/// A node heard for the first time.
final class NewNodeEvent extends TimelineEvent {
  const NewNodeEvent(
    super.at, {
    required this.name,
    required this.nodeKey,
    required this.type,
  });

  final String name;
  final String nodeKey;
  final int type;

  @override
  TimelineKind get kind => TimelineKind.newNode;
}

/// A node's signal moved by [signalChangeDb] or more from its recent
/// average.
final class SignalEvent extends TimelineEvent {
  const SignalEvent(
    super.at, {
    required this.name,
    required this.nodeKey,
    required this.from,
    required this.to,
  });

  final String name;
  final String nodeKey;

  /// Average of the previous hearings, dB.
  final double from;

  /// This hearing, dB.
  final double to;

  bool get better => to > from;

  @override
  TimelineKind get kind => TimelineKind.signal;
}

/// A position: shared in a chat, or a node advertising a new place.
final class PositionEvent extends TimelineEvent {
  const PositionEvent(
    super.at, {
    required this.name,
    required this.position,
    this.chat,
    this.nodeKey,
  });

  final String name;
  final LatLng position;

  /// The chat it was shared in, for shared positions.
  final String? chat;

  /// The node, for advertised positions.
  final String? nodeKey;

  @override
  TimelineKind get kind => TimelineKind.position;
}

/// Change in dB from the recent average that counts as a signal change.
const signalChangeDb = 6.0;

/// Hearings averaged to compare against.
const signalAverageOver = 5;

/// A node must move this far between adverts to count as a new place.
const positionMoveMetres = 500.0;

/// Builds the feed from [messages] (with [chatTitles] by thread), the
/// journal [nodes] and their [sightings] (oldest first), keeping what
/// happened at or after [since]. Newest first.
List<TimelineEvent> buildTimeline({
  required List<Message> messages,
  required Map<String, String> chatTitles,
  required List<JournalNode> nodes,
  required Map<String, List<JournalSighting>> sightings,
  required DateTime since,
}) {
  final out = <TimelineEvent>[];
  bool inRange(DateTime t) => !t.isBefore(since);

  for (final m in messages) {
    final at = DateTime.fromMillisecondsSinceEpoch(m.storedAt);
    if (!inRange(at)) continue;
    final chat = chatTitles[m.thread] ?? m.thread;
    final place = sharedPosition(m.body);
    if (place != null) {
      out.add(
        PositionEvent(
          at,
          name: m.outgoing ? '' : (m.senderName ?? chat),
          position: place,
          chat: chat,
        ),
      );
    }
    out.add(
      MessageEvent(
        at,
        chat: chat,
        thread: m.thread,
        body: m.body,
        outgoing: m.outgoing,
        sender: m.senderName,
      ),
    );
  }

  const distance = Distance();
  for (final node in nodes) {
    final first = DateTime.fromMillisecondsSinceEpoch(node.firstHeard);
    if (inRange(first)) {
      out.add(
        NewNodeEvent(
          first,
          name: node.name,
          nodeKey: node.nodeKey,
          type: node.type,
        ),
      );
    }
    final heard = sightings[node.nodeKey] ?? const <JournalSighting>[];
    final recent = <double>[];
    LatLng? lastPlace;
    for (final s in heard) {
      final at = DateTime.fromMillisecondsSinceEpoch(s.at);
      if (s.snr case final snr?) {
        if (recent.length >= 2) {
          final average = recent.reduce((a, b) => a + b) / recent.length;
          if ((snr - average).abs() >= signalChangeDb && inRange(at)) {
            out.add(
              SignalEvent(
                at,
                name: node.name,
                nodeKey: node.nodeKey,
                from: average,
                to: snr,
              ),
            );
          }
        }
        recent.add(snr);
        if (recent.length > signalAverageOver) recent.removeAt(0);
      }
      if (s.latitude != null && s.longitude != null) {
        final place = LatLng(s.latitude!, s.longitude!);
        final moved =
            lastPlace == null ||
            distance(lastPlace, place) >= positionMoveMetres;
        // The first place counts only for nodes first heard in range, so
        // old nodes don't all appear as "new place".
        if (moved && inRange(at) && (lastPlace != null || inRange(first))) {
          out.add(
            PositionEvent(
              at,
              name: node.name,
              position: place,
              nodeKey: node.nodeKey,
            ),
          );
        }
        if (moved) lastPlace = place;
      }
    }
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

/// Only events of [kinds] whose text contains [query] (any case).
List<TimelineEvent> filterTimeline(
  List<TimelineEvent> events,
  Set<TimelineKind> kinds, {
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return [
    for (final e in events)
      if (kinds.contains(e.kind) && (q.isEmpty || _text(e).contains(q))) e,
  ];
}

String _text(TimelineEvent e) => switch (e) {
  MessageEvent(:final chat, :final body, :final sender) =>
    '$chat ${sender ?? ''} $body',
  NewNodeEvent(:final name) => name,
  SignalEvent(:final name) => name,
  PositionEvent(:final name, :final chat) => '$name ${chat ?? ''}',
}.toLowerCase();

/// Loads the feed for [radioKey] since [since].
Future<List<TimelineEvent>> loadTimeline(
  MeshStore store,
  MeshDatabase db,
  String radioKey,
  DateTime since,
) async {
  final messages = await store.fieldLog(radioKey, since: since, limit: 1000);
  final titles = <String, String>{};
  for (final m in messages) {
    titles[m.thread] ??= (await chatLinkFor(store, radioKey, m.thread)).title;
  }
  final nodes = await (db.select(
    db.journalNodes,
  )..where((n) => n.radioKey.equals(radioKey))).get();
  // Look back a little further, so signal averages have history.
  final sightings = await sightingsSince(
    db,
    radioKey,
    since.subtract(const Duration(days: 2)),
  );
  return buildTimeline(
    messages: messages,
    chatTitles: titles,
    nodes: nodes,
    sightings: sightings,
    since: since,
  );
}
