import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/connection.dart';
import '../app/follow.dart';
import '../app/position.dart';
import '../l10n/l10n.dart';
import 'map_tab.dart' show mapTilesProvider;
import 'node_details.dart' show distanceText;

/// Starts following a node for 15 minutes and opens the live view.
void openFollow(
  BuildContext context,
  WidgetRef ref, {
  required String nodeKey,
  required String name,
  LatLng? lastKnown,
}) {
  final radioKey = ref.read(radioKeyProvider);
  if (radioKey == null) return;
  final follow = ref.read(followProvider.notifier);
  if (!follow.isFollowing(nodeKey)) {
    follow.start(
      radioKey: radioKey,
      nodeKey: nodeKey,
      name: name,
      lastKnown: lastKnown,
    );
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          FollowScreen(nodeKey: nodeKey, name: name, lastKnown: lastKnown),
    ),
  );
}

/// The followed node's trail on a map, how far and which way it is from
/// the phone, and the time left.
class FollowScreen extends ConsumerStatefulWidget {
  const FollowScreen({
    required this.nodeKey,
    required this.name,
    this.lastKnown,
    super.key,
  });

  final String nodeKey;
  final String name;
  final LatLng? lastKnown;

  @override
  ConsumerState<FollowScreen> createState() => _FollowScreenState();
}

class _FollowScreenState extends ConsumerState<FollowScreen> {
  Timer? _tick;
  LatLng? _me;
  final _map = MapController();
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_findMe());
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (t.tick % 30 == 0) unawaited(_findMe());
      setState(() {});
    });
  }

  Future<void> _findMe() async {
    try {
      final me = await ref.read(allowedPhonePositionProvider)();
      if (mounted && me != null) setState(() => _me = me);
    } on Object {
      // No position this time.
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  static const _compass = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(followProvider);
    final on = session?.nodeKey == widget.nodeKey;
    final trail = on ? session!.trail : const <FollowPoint>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.followTitle(widget.name)),
        actions: [
          if (on)
            IconButton(
              key: const Key('follow-ask'),
              tooltip: l10n.followAskNow,
              icon: const Icon(Icons.my_location),
              onPressed: () =>
                  unawaited(ref.read(followProvider.notifier).askNow()),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: on ? _status(session!) : _stopped(),
          ),
          Expanded(child: _mapView(trail)),
        ],
      ),
    );
  }

  Widget _status(FollowSession s) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final follow = ref.read(followProvider.notifier);
    final last = s.trail.isEmpty ? null : s.trail.last;
    final me = _me;
    final String headline;
    if (last == null) {
      headline = l10n.followWaiting;
    } else if (me == null) {
      headline = l10n.followNoOwnPosition;
    } else {
      final deg = (const Distance().bearing(me, last.where) + 360) % 360;
      headline = l10n.followFromYou(
        distanceText(me, last.where),
        _compass[((deg + 22.5) ~/ 45) % 8],
        deg.round(),
      );
    }
    final left = follow.remaining();
    final age = last == null
        ? null
        : ref.read(followClockProvider)().difference(last.at);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(headline, style: theme.textTheme.titleMedium)),
            Semantics(
              label: l10n.followTimeLeft(left.inMinutes + 1),
              excludeSemantics: true,
              child: Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text(_clock(left)),
              ),
            ),
          ],
        ),
        Text(
          [
            if (age != null)
              l10n.followLastFix(
                age.inSeconds < 60
                    ? l10n.followSecondsAgo(age.inSeconds)
                    : l10n.followMinutesAgo(age.inMinutes),
              ),
            l10n.followAnswers(s.answered, s.asked),
            l10n.followPoints(s.trail.length),
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(l10n.followHint, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('follow-stop'),
              onPressed: follow.stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.followStop),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stopped() {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(child: Text(l10n.followStopped)),
        FilledButton.icon(
          key: const Key('follow-again'),
          onPressed: () => openFollowAgain(),
          icon: const Icon(Icons.radar),
          label: Text(l10n.followButton),
        ),
      ],
    );
  }

  void openFollowAgain() {
    final radioKey = ref.read(radioKeyProvider);
    if (radioKey == null) return;
    ref
        .read(followProvider.notifier)
        .start(
          radioKey: radioKey,
          nodeKey: widget.nodeKey,
          name: widget.name,
          lastKnown: widget.lastKnown,
        );
  }

  Widget _mapView(List<FollowPoint> trail) {
    final l10n = context.l10n;
    final points = [for (final p in trail) p.where];
    final me = _me;
    final all = [...points, ?me];
    if (all.isEmpty && widget.lastKnown != null) all.add(widget.lastKnown!);
    if (all.isEmpty) return Center(child: Text(l10n.followWaiting));
    if (!_moved && all.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _moved) return;
        try {
          _map.fitCamera(
            CameraFit.coordinates(
              coordinates: all,
              padding: const EdgeInsets.all(48),
              maxZoom: 17,
            ),
          );
        } on Object {
          // Not laid out yet; the next frame fits it.
        }
      });
    }
    final scheme = Theme.of(context).colorScheme;
    final tiles = ref.watch(mapTilesProvider);
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: all.last,
        initialZoom: 15,
        onPositionChanged: (_, gesture) {
          if (gesture) _moved = true;
        },
      ),
      children: [
        ?tiles,
        PolylineLayer(
          polylines: [
            if (points.length > 1)
              Polyline(points: points, strokeWidth: 4, color: scheme.primary),
            if (me != null && points.isNotEmpty)
              Polyline(
                points: [me, points.last],
                strokeWidth: 2,
                color: scheme.outline,
                pattern: StrokePattern.dashed(segments: const [8, 6]),
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final p in points.take(points.length - 1))
              Marker(
                point: p,
                width: 10,
                height: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (points.isNotEmpty)
              Marker(
                point: points.last,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.person_pin_circle,
                  size: 40,
                  color: scheme.primary,
                  semanticLabel: widget.name,
                ),
              ),
            if (me != null)
              Marker(
                point: me,
                width: 28,
                height: 28,
                child: Icon(
                  Icons.navigation,
                  color: scheme.tertiary,
                  semanticLabel: l10n.followYou,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
