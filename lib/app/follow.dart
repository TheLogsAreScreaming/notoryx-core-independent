/// Following one node's position live for a short time.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import 'connection.dart';

/// How long a follow runs before it stops by itself.
const followLength = Duration(minutes: 15);

/// How often the followed node is asked where it is.
const followAskEvery = Duration(minutes: 3);

/// One place the node was seen; [asked] when it answered a request rather
/// than announcing itself.
typedef FollowPoint = ({DateTime at, LatLng where, bool asked});

/// What is being followed now.
typedef FollowSession = ({
  String radioKey,
  String nodeKey,
  String name,
  DateTime startedAt,
  List<FollowPoint> trail,
  int asked,
  int answered,
});

/// The clock follow uses; tests replace it.
final followClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Asks a node where it is; null when it couldn't be asked or answered
/// without a position. Tests replace it.
final followAskProvider = Provider<Future<LatLng?>? Function(String nodeKey)>(
  (ref) => (nodeKey) {
    final state = ref.read(connectionProvider);
    if (state is! Connected) return null;
    return state.sync
        .requestTelemetry(PublicKey.fromHex(nodeKey))
        .then((readings) => readings == null ? null : positionIn(readings));
  },
);

/// The first usable GPS reading in a telemetry reply.
LatLng? positionIn(List<LppReading> readings) {
  for (final r in readings) {
    if (r.kind != LppKind.gps || r.values.length < 2) continue;
    final lat = r.values[0], lon = r.values[1];
    if ((lat == 0 && lon == 0) || lat.abs() > 90 || lon.abs() > 180) continue;
    return LatLng(lat, lon);
  }
  return null;
}

/// The node being followed, or null.
final followProvider = NotifierProvider<FollowController, FollowSession?>(
  FollowController.new,
);

/// Starts, feeds and stops a follow. The trail is kept in memory only.
class FollowController extends Notifier<FollowSession?> {
  Timer? _askTimer;
  Timer? _endTimer;
  ProviderSubscription<AsyncValue<List<Contact>>>? _contacts;

  /// Moves shorter than this only refresh the last point.
  static const minMoveMetres = 5.0;

  @override
  FollowSession? build() {
    ref.onDispose(_cancel);
    return null;
  }

  DateTime get _now => ref.read(followClockProvider)();

  /// Time left in the follow, zero when none runs.
  Duration remaining() {
    final s = state;
    if (s == null) return Duration.zero;
    final left = s.startedAt.add(followLength).difference(_now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isFollowing(String nodeKey) => state?.nodeKey == nodeKey;

  /// Starts following [nodeKey]; any other follow stops first.
  void start({
    required String radioKey,
    required String nodeKey,
    required String name,
    LatLng? lastKnown,
  }) {
    _cancel();
    state = (
      radioKey: radioKey,
      nodeKey: nodeKey,
      name: name,
      startedAt: _now,
      trail: [
        if (lastKnown != null) (at: _now, where: lastKnown, asked: false),
      ],
      asked: 0,
      answered: 0,
    );
    _contacts = ref.listen(contactsProvider(radioKey), (_, next) {
      final list = next.value;
      if (list == null) return;
      for (final c in list) {
        if (c.publicKey != nodeKey) continue;
        if (c.latitude == null || c.longitude == null) return;
        _add(LatLng(c.latitude!, c.longitude!), asked: false);
        return;
      }
    });
    _endTimer = Timer(followLength, stop);
    _askTimer = Timer.periodic(followAskEvery, (_) => unawaited(askNow()));
    unawaited(askNow());
  }

  /// Asks the node now.
  Future<void> askNow() async {
    final s = state;
    if (s == null) return;
    final reply = ref.read(followAskProvider)(s.nodeKey);
    if (reply == null) return;
    state = (
      radioKey: s.radioKey,
      nodeKey: s.nodeKey,
      name: s.name,
      startedAt: s.startedAt,
      trail: s.trail,
      asked: s.asked + 1,
      answered: s.answered,
    );
    LatLng? where;
    try {
      where = await reply;
    } on Object {
      return;
    }
    final now = state;
    if (now == null || now.nodeKey != s.nodeKey) return;
    state = (
      radioKey: now.radioKey,
      nodeKey: now.nodeKey,
      name: now.name,
      startedAt: now.startedAt,
      trail: now.trail,
      asked: now.asked,
      answered: now.answered + 1,
    );
    if (where != null) _add(where, asked: true);
  }

  void _add(LatLng where, {required bool asked}) {
    final s = state;
    if (s == null) return;
    final trail = [...s.trail];
    final point = (at: _now, where: where, asked: asked);
    if (trail.isNotEmpty) {
      final last = trail.last;
      if (!asked && last.where == where) return;
      final metres = const Distance().as(LengthUnit.Meter, last.where, where);
      if (metres < minMoveMetres) {
        trail[trail.length - 1] = point;
      } else {
        trail.add(point);
      }
    } else {
      trail.add(point);
    }
    state = (
      radioKey: s.radioKey,
      nodeKey: s.nodeKey,
      name: s.name,
      startedAt: s.startedAt,
      trail: trail,
      asked: s.asked,
      answered: s.answered,
    );
  }

  /// Stops and forgets the trail.
  void stop() {
    _cancel();
    state = null;
  }

  void _cancel() {
    _askTimer?.cancel();
    _endTimer?.cancel();
    _contacts?.close();
    _askTimer = null;
    _endTimer = null;
    _contacts = null;
  }
}
