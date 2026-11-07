/// SOS and check-ins: a one-tap call for help or "I'm OK" with a position,
/// and an optional timer that reminds the person to check in and, if they
/// don't, tells their chosen chat.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'notifications.dart';
import 'position.dart';

// Setting keys.
const safetyTargetSetting = 'safety_target';
const checkInEverySetting = 'checkin_every_min';
const checkInDueSetting = 'checkin_due';
const checkInAlertSetting = 'checkin_alert';
const checkInLastSetting = 'checkin_last';

/// The intervals offered for check-ins.
const checkInChoices = [
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 4),
  Duration(hours: 8),
];

/// What the person has set up, and where the check-in timer stands.
final class SafetyState {
  const SafetyState({
    this.target,
    this.every,
    this.due,
    this.lastCheckIn,
    this.alertOnMiss = true,
  });

  /// The chat SOS and check-ins go to: a thread such as `c:0` or `d:<key>`.
  final String? target;

  /// How often a check-in is expected; null when the timer is off.
  final Duration? every;

  /// When the next check-in is due.
  final DateTime? due;
  final DateTime? lastCheckIn;

  /// Whether a missed check-in is sent to [target] after the grace period.
  final bool alertOnMiss;

  bool get timerOn => every != null && due != null;
}

/// The clock the timer runs on. Tests replace it.
final safetyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// How long after the reminder a missed check-in is sent to the chat.
final checkInGraceProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 15),
);

final safetyProvider = AsyncNotifierProvider<Safety, SafetyState>(Safety.new);

/// Why something couldn't be sent.
final class SafetyException implements Exception {
  const SafetyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Safety extends AsyncNotifier<SafetyState> {
  MeshStore get _store => ref.read(storeProvider);
  DateTime _now() => ref.read(safetyClockProvider)();

  @override
  Future<SafetyState> build() async {
    final store = ref.read(storeProvider);
    final minutes = int.tryParse(
      await store.setting(checkInEverySetting) ?? '',
    );
    DateTime? at(String? v) {
      final ms = int.tryParse(v ?? '');
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return SafetyState(
      target: await store.setting(safetyTargetSetting),
      every: minutes == null || minutes <= 0
          ? null
          : Duration(minutes: minutes),
      due: at(await store.setting(checkInDueSetting)),
      lastCheckIn: at(await store.setting(checkInLastSetting)),
      alertOnMiss: await store.setting(checkInAlertSetting) != '0',
    );
  }

  SafetyState get _current => state.value ?? const SafetyState();

  Future<void> _set(String key, String? value) => value == null
      ? _store.removeSetting(key)
      : _store.saveSetting(key, value);

  Future<void> setTarget(String thread) async {
    await _set(safetyTargetSetting, thread);
    final s = _current;
    state = AsyncData(
      SafetyState(
        target: thread,
        every: s.every,
        due: s.due,
        lastCheckIn: s.lastCheckIn,
        alertOnMiss: s.alertOnMiss,
      ),
    );
  }

  Future<void> setAlertOnMiss(bool on) async {
    await _set(checkInAlertSetting, on ? '1' : '0');
    final s = _current;
    state = AsyncData(
      SafetyState(
        target: s.target,
        every: s.every,
        due: s.due,
        lastCheckIn: s.lastCheckIn,
        alertOnMiss: on,
      ),
    );
  }

  /// Starts the timer: the first check-in is due [every] from now.
  Future<void> startTimer(Duration every) => _schedule(every, _now());

  /// Stops expecting check-ins.
  Future<void> stopTimer() async {
    await _set(checkInEverySetting, null);
    await _set(checkInDueSetting, null);
    final s = _current;
    state = AsyncData(
      SafetyState(
        target: s.target,
        lastCheckIn: s.lastCheckIn,
        alertOnMiss: s.alertOnMiss,
      ),
    );
  }

  Future<void> _schedule(
    Duration every,
    DateTime from, {
    DateTime? last,
  }) async {
    final due = from.add(every);
    await _set(checkInEverySetting, '${every.inMinutes}');
    await _set(checkInDueSetting, '${due.millisecondsSinceEpoch}');
    if (last != null) {
      await _set(checkInLastSetting, '${last.millisecondsSinceEpoch}');
    }
    final s = _current;
    state = AsyncData(
      SafetyState(
        target: s.target,
        every: every,
        due: due,
        lastCheckIn: last ?? s.lastCheckIn,
        alertOnMiss: s.alertOnMiss,
      ),
    );
  }

  /// Sends "I'm OK" with a position, and restarts the timer if it's on.
  Future<void> checkIn() async {
    final now = _now();
    await _send(checkInText(await _position()));
    final every = _current.every;
    if (every != null) {
      await _schedule(every, now, last: now);
    } else {
      await _set(checkInLastSetting, '${now.millisecondsSinceEpoch}');
      final s = _current;
      state = AsyncData(
        SafetyState(
          target: s.target,
          lastCheckIn: now,
          alertOnMiss: s.alertOnMiss,
        ),
      );
    }
  }

  /// Sends a call for help with a position.
  Future<void> sendSos() async => _send(sosText(await _position()));

  /// Tells the chat a check-in was missed. The timer stops so it isn't
  /// sent again; checking in starts it again.
  Future<void> sendMissed() async {
    final due = _current.due;
    await _send(missedText(await _position(), due: due));
    await _set(checkInDueSetting, null);
    final s = _current;
    state = AsyncData(
      SafetyState(
        target: s.target,
        every: s.every,
        lastCheckIn: s.lastCheckIn,
        alertOnMiss: s.alertOnMiss,
      ),
    );
  }

  /// The phone's position, else the radio's advertised one.
  Future<LatLng?> _position() async {
    try {
      final here = await ref
          .read(phonePositionProvider)()
          .timeout(const Duration(seconds: 15));
      if (here != null) return here;
    } on Object {
      // Fall back to the radio's position below.
    }
    final state = ref.read(connectionProvider);
    if (state is Connected) {
      final self = state.radio.self;
      if (self.latitude case final lat? when self.longitude != null) {
        return LatLng(lat, self.longitude!);
      }
    }
    return null;
  }

  Future<void> _send(String text) async {
    final target = _current.target;
    if (target == null) {
      throw const SafetyException('Choose where to send it first.');
    }
    final state = ref.read(connectionProvider);
    if (state is! Connected) {
      throw const SafetyException('Not connected to a radio.');
    }
    final id = target.substring(2);
    if (target.startsWith('c:')) {
      await state.sync.sendChannel(int.parse(id), text);
    } else {
      await state.sync.sendDirect(PublicKey.fromHex(id), text);
    }
  }
}

String _where(LatLng? p) => p == null
    ? 'Position unknown.'
    : 'Position ${p.latitude.toStringAsFixed(5)},'
          '${p.longitude.toStringAsFixed(5)}';

/// The SOS message.
String sosText(LatLng? p) => 'SOS - I need help. ${_where(p)}';

/// The check-in message.
String checkInText(LatLng? p) => "Check-in: I'm OK. ${_where(p)}";

/// The message sent when a check-in is missed.
String missedText(LatLng? p, {DateTime? due}) {
  final when = due == null
      ? ''
      : ' (due ${due.hour.toString().padLeft(2, '0')}:'
            '${due.minute.toString().padLeft(2, '0')})';
  return 'Missed check-in$when. No reply from me. Last ${_where(p)}';
}

/// Notification id for the check-in reminder, kept apart from message ids.
const checkInReminderId = 0x7FFF0001;

/// Runs the check-in timer: reminds the person when a check-in is due,
/// and after [checkInGraceProvider] sends the missed check-in to the chat
/// (when they chose that). Runs while the app does, which is all the time
/// a radio is connected thanks to the background connection.
final checkInWatchdogProvider = Provider<void>((ref) {
  Timer? timer;
  var reminded = false;
  DateTime? lastDue;

  Future<void> fire() async {
    final s = ref.read(safetyProvider).value;
    final due = s?.due;
    if (s == null || due == null) return;
    final now = ref.read(safetyClockProvider)();
    final grace = ref.read(checkInGraceProvider);
    final notifier = ref.read(messageNotifierProvider);
    final target = s.target;
    final radioKey = ref.read(radioKeyProvider);
    if (!now.isBefore(due) && !reminded) {
      reminded = true;
      if (target != null && radioKey != null) {
        final chat = await chatLinkFor(
          ref.read(storeProvider),
          radioKey,
          target,
        );
        await notifier.show(
          id: checkInReminderId,
          title: 'Check-in due',
          body: s.alertOnMiss
              ? 'Open NOTORYX and check in, or ${chat.title} is told in '
                    '${grace.inMinutes} minutes.'
              : 'Open NOTORYX and check in.',
          chat: chat,
        );
      }
    }
    if (s.alertOnMiss && !now.isBefore(due.add(grace))) {
      try {
        await ref.read(safetyProvider.notifier).sendMissed();
      } on Object catch (e) {
        // Not connected: try again on the next tick.
        ref.read(connectionLogProvider).add('missed check-in: $e');
      }
    }
  }

  void follow(SafetyState? s) {
    final due = s?.due;
    if (due != lastDue) {
      lastDue = due;
      reminded = false;
    }
    timer?.cancel();
    timer = null;
    if (due == null) return;
    // A minute tick is plenty for a timer measured in hours, and keeps
    // working after the phone's clock jumps.
    timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(fire()),
    );
    unawaited(fire());
  }

  ref.onDispose(() => timer?.cancel());
  follow(ref.read(safetyProvider).value);
  ref.listen(safetyProvider, (_, next) => follow(next.value));
});
