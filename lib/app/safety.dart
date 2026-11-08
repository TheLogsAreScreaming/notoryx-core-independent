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
const sosSinceSetting = 'sos_since';
const sosLastSetting = 'sos_last';
const sosSendsSetting = 'sos_sends';
const sosAnsweredSetting = 'sos_answered';

/// The intervals offered for check-ins.
const checkInChoices = [
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 4),
  Duration(hours: 8),
];

/// What the person has set up, where the check-in timer stands, and
/// whether an SOS is going on.
final class SafetyState {
  const SafetyState({
    this.target,
    this.every,
    this.due,
    this.lastCheckIn,
    this.alertOnMiss = true,
    this.sosSince,
    this.sosLastSent,
    this.sosSends = 0,
    this.sosAnsweredBy,
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

  /// When the SOS going on now was first sent; null when there is none.
  final DateTime? sosSince;

  /// When it was last sent, and how many times so far.
  final DateTime? sosLastSent;
  final int sosSends;

  /// Who answered it. Once someone has, it stops repeating.
  final String? sosAnsweredBy;

  bool get timerOn => every != null && due != null;
  bool get sosActive => sosSince != null;

  /// Whether the SOS still repeats.
  bool get sosRepeating => sosActive && sosAnsweredBy == null;

  SafetyState copyWith({
    Object? target = _keep,
    Object? every = _keep,
    Object? due = _keep,
    Object? lastCheckIn = _keep,
    bool? alertOnMiss,
    Object? sosSince = _keep,
    Object? sosLastSent = _keep,
    int? sosSends,
    Object? sosAnsweredBy = _keep,
  }) => SafetyState(
    target: target == _keep ? this.target : target as String?,
    every: every == _keep ? this.every : every as Duration?,
    due: due == _keep ? this.due : due as DateTime?,
    lastCheckIn: lastCheckIn == _keep
        ? this.lastCheckIn
        : lastCheckIn as DateTime?,
    alertOnMiss: alertOnMiss ?? this.alertOnMiss,
    sosSince: sosSince == _keep ? this.sosSince : sosSince as DateTime?,
    sosLastSent: sosLastSent == _keep
        ? this.sosLastSent
        : sosLastSent as DateTime?,
    sosSends: sosSends ?? this.sosSends,
    sosAnsweredBy: sosAnsweredBy == _keep
        ? this.sosAnsweredBy
        : sosAnsweredBy as String?,
  );
}

/// Marks a [SafetyState.copyWith] field as unchanged, so null can clear one.
const _keep = Object();

/// The clock the timers run on. Tests replace it.
final safetyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// How long after the reminder a missed check-in is sent to the chat.
final checkInGraceProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 15),
);

/// How often an unanswered SOS is sent again.
final sosRepeatProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
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
      sosSince: at(await store.setting(sosSinceSetting)),
      sosLastSent: at(await store.setting(sosLastSetting)),
      sosSends: int.tryParse(await store.setting(sosSendsSetting) ?? '') ?? 0,
      sosAnsweredBy: await store.setting(sosAnsweredSetting),
    );
  }

  SafetyState get _current => state.value ?? const SafetyState();

  Future<void> _set(String key, Object? value) => value == null
      ? _store.removeSetting(key)
      : _store.saveSetting(
          key,
          value is DateTime ? '${value.millisecondsSinceEpoch}' : '$value',
        );

  Future<void> setTarget(String thread) async {
    await _set(safetyTargetSetting, thread);
    state = AsyncData(_current.copyWith(target: thread));
  }

  Future<void> setAlertOnMiss(bool on) async {
    await _set(checkInAlertSetting, on ? '1' : '0');
    state = AsyncData(_current.copyWith(alertOnMiss: on));
  }

  /// Starts the timer: the first check-in is due [every] from now.
  Future<void> startTimer(Duration every) => _schedule(every, _now());

  /// Stops expecting check-ins.
  Future<void> stopTimer() async {
    await _set(checkInEverySetting, null);
    await _set(checkInDueSetting, null);
    state = AsyncData(_current.copyWith(every: null, due: null));
  }

  Future<void> _schedule(
    Duration every,
    DateTime from, {
    DateTime? last,
  }) async {
    final due = from.add(every);
    await _set(checkInEverySetting, every.inMinutes);
    await _set(checkInDueSetting, due);
    if (last != null) await _set(checkInLastSetting, last);
    state = AsyncData(
      _current.copyWith(
        every: every,
        due: due,
        lastCheckIn: last ?? _current.lastCheckIn,
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
      await _set(checkInLastSetting, now);
      state = AsyncData(_current.copyWith(lastCheckIn: now));
    }
  }

  /// Sends a call for help with a position, and keeps sending it every
  /// [sosRepeatProvider] until someone answers or [endSos] is called.
  /// While one is going on, this sends it again straight away.
  Future<void> sendSos() async {
    final now = _now();
    final s = _current;
    final sends = s.sosActive ? s.sosSends + 1 : 1;
    await _send(sosText(await _position(), send: sends));
    final since = s.sosSince ?? now;
    await _set(sosSinceSetting, since);
    await _set(sosLastSetting, now);
    await _set(sosSendsSetting, sends);
    state = AsyncData(
      _current.copyWith(sosSince: since, sosLastSent: now, sosSends: sends),
    );
  }

  /// Someone answered the SOS: it stops repeating, but stays on until
  /// [endSos].
  Future<void> markSosAnswered(String who) async {
    if (!_current.sosRepeating) return;
    await _set(sosAnsweredSetting, who);
    state = AsyncData(_current.copyWith(sosAnsweredBy: who));
  }

  /// Ends the SOS. With [allClear], tells the chat "I'm safe" first.
  Future<void> endSos({bool allClear = true}) async {
    if (allClear) await _send(safeText(await _position()));
    for (final key in [
      sosSinceSetting,
      sosLastSetting,
      sosSendsSetting,
      sosAnsweredSetting,
    ]) {
      await _set(key, null);
    }
    state = AsyncData(
      _current.copyWith(
        sosSince: null,
        sosLastSent: null,
        sosSends: 0,
        sosAnsweredBy: null,
      ),
    );
  }

  /// Tells the chat a check-in was missed. The timer stops so it isn't
  /// sent again; checking in starts it again.
  Future<void> sendMissed() async {
    final due = _current.due;
    await _send(missedText(await _position(), due: due));
    await _set(checkInDueSetting, null);
    state = AsyncData(_current.copyWith(due: null));
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

String _where(LatLng? p, {String lead = 'Position'}) => p == null
    ? '$lead unknown.'
    : '$lead ${p.latitude.toStringAsFixed(5)},'
          '${p.longitude.toStringAsFixed(5)}';

/// The SOS message. Repeats carry their number, so people can tell it's
/// still going on and see the newest position.
String sosText(LatLng? p, {int send = 1}) =>
    '${send > 1 ? 'SOS ($send)' : 'SOS'} - I need help. ${_where(p)}';

/// The all-clear that ends an SOS.
String safeText(LatLng? p) => "I'm safe now - SOS over. ${_where(p)}";

/// The check-in message.
String checkInText(LatLng? p) => "Check-in: I'm OK. ${_where(p)}";

/// The message sent when a check-in is missed.
String missedText(LatLng? p, {DateTime? due}) {
  final when = due == null
      ? ''
      : ' (due ${due.hour.toString().padLeft(2, '0')}:'
            '${due.minute.toString().padLeft(2, '0')})';
  return 'Missed check-in$when. No reply from me. ${_where(p, lead: 'Last known position')}';
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

/// Whether [m], arriving in the SOS chat, answers the SOS. Anything in a
/// direct chat does. On a channel, where others keep talking, only a
/// message that mentions [myName] or says SOS does.
bool answersSos(Message m, {String? myName}) {
  if (m.kind == MessageKind.direct) return true;
  final text = m.body.toLowerCase();
  if (RegExp(r'\bsos\b').hasMatch(text)) return true;
  final name = myName?.trim().toLowerCase();
  return name != null && name.isNotEmpty && text.contains(name);
}

/// Keeps an SOS going: sends it again every [sosRepeatProvider] until it
/// is answered or ended, and counts any message arriving in the SOS chat
/// after it started as an answer.
final sosWatchdogProvider = Provider<void>((ref) {
  Timer? timer;
  StreamSubscription<Message>? replies;

  Future<void> tick() async {
    final s = ref.read(safetyProvider).value;
    final last = s?.sosLastSent;
    if (s == null || !s.sosRepeating || last == null) return;
    final now = ref.read(safetyClockProvider)();
    if (now.difference(last) < ref.read(sosRepeatProvider)) return;
    try {
      await ref.read(safetyProvider.notifier).sendSos();
    } on Object catch (e) {
      // Not connected: try again on the next tick.
      ref.read(connectionLogProvider).add('SOS repeat: $e');
    }
  }

  Future<void> heard(Message m) async {
    final s = ref.read(safetyProvider).value;
    final since = s?.sosSince;
    if (s == null || !s.sosRepeating || since == null) return;
    if (m.outgoing || m.thread != s.target) return;
    if (m.storedAt < since.millisecondsSinceEpoch) return;
    final state = ref.read(connectionProvider);
    final me = state is Connected ? state.radio.self.name : null;
    if (!answersSos(m, myName: me)) return;
    final who = m.kind == MessageKind.channel
        ? m.senderName ?? 'Someone'
        : (await chatLinkFor(
            ref.read(storeProvider),
            m.radioKey,
            m.thread,
          )).title;
    await ref.read(safetyProvider.notifier).markSosAnswered(who);
  }

  void followConnection(RadioConnectionState state) {
    unawaited(replies?.cancel());
    replies = state is Connected
        ? state.sync.incoming.listen((m) => unawaited(heard(m)))
        : null;
  }

  void followSafety(SafetyState? s) {
    final repeating = s?.sosRepeating ?? false;
    if (repeating && timer == null) {
      timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(tick()),
      );
    } else if (!repeating) {
      timer?.cancel();
      timer = null;
    }
  }

  ref.onDispose(() {
    timer?.cancel();
    unawaited(replies?.cancel());
  });
  followConnection(ref.read(connectionProvider));
  ref.listen(connectionProvider, (_, next) => followConnection(next));
  followSafety(ref.read(safetyProvider).value);
  ref.listen(safetyProvider, (_, next) => followSafety(next.value));
});
