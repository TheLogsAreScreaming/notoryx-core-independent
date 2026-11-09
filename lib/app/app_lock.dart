/// Locking the app behind the phone's fingerprint, face or screen lock.
///
/// The lock only covers the screen. The radio connection, SOS repeats and
/// check-in reminders keep running behind it.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'connection.dart';

const appLockSetting = 'app_lock';

/// How long the app can be away before it locks again.
const appLockChoices = <Duration>[
  Duration.zero,
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
];

const appLockDefault = Duration(minutes: 1);

/// What came of asking the phone who is holding it.
enum AuthResult {
  success,
  failed,

  /// The phone has no lock set, so there's nothing to check against.
  unavailable,
}

typedef AppAuthenticator = Future<AuthResult> Function();

Future<AuthResult> _askPhone() async {
  final auth = LocalAuthentication();
  try {
    if (!await auth.isDeviceSupported()) return AuthResult.unavailable;
    final ok = await auth.authenticate(
      localizedReason: 'Unlock NOTORYX Core',
      persistAcrossBackgrounding: true,
    );
    return ok ? AuthResult.success : AuthResult.failed;
  } on LocalAuthException catch (e) {
    return switch (e.code) {
      LocalAuthExceptionCode.noCredentialsSet ||
      LocalAuthExceptionCode.noBiometricHardware => AuthResult.unavailable,
      _ => AuthResult.failed,
    };
  } on PlatformException {
    return AuthResult.failed;
  }
}

final appAuthenticatorProvider = Provider<AppAuthenticator>((ref) => _askPhone);

/// The clock the lock's timeout runs on.
final appLockClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final class AppLockState {
  const AppLockState({
    this.loaded = false,
    this.enabled = false,
    this.timeout = appLockDefault,
    this.locked = false,
  });

  /// False until the setting is read. Nothing shows until then, so a locked
  /// app can't flash its chats at launch.
  final bool loaded;
  final bool enabled;
  final Duration timeout;
  final bool locked;

  AppLockState copyWith({bool? enabled, Duration? timeout, bool? locked}) =>
      AppLockState(
        loaded: true,
        enabled: enabled ?? this.enabled,
        timeout: timeout ?? this.timeout,
        locked: locked ?? this.locked,
      );
}

/// Reads whether the lock is on, from the stored [raw] setting.
({bool enabled, Duration timeout}) parseAppLock(String? raw) {
  if (raw == null) return (enabled: false, timeout: appLockDefault);
  try {
    final json = jsonDecode(raw) as Map<String, Object?>;
    return (
      enabled: json['enabled'] == true,
      timeout: Duration(seconds: json['seconds']! as int),
    );
  } on Object {
    return (enabled: false, timeout: appLockDefault);
  }
}

class AppLock extends Notifier<AppLockState> {
  DateTime? _leftAt;
  bool _asking = false;

  @override
  AppLockState build() {
    Future.microtask(_load);
    return const AppLockState();
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(appLockSetting);
    if (!ref.mounted) return;
    final saved = parseAppLock(raw);
    state = state.copyWith(
      enabled: saved.enabled,
      timeout: saved.timeout,
      locked: saved.enabled,
    );
  }

  Future<void> _save() => ref
      .read(storeProvider)
      .saveSetting(
        appLockSetting,
        jsonEncode({
          'enabled': state.enabled,
          'seconds': state.timeout.inSeconds,
        }),
      );

  /// The app went to the background.
  void left() {
    // The phone's own unlock prompt also sends the app to the background.
    if (_asking) return;
    _leftAt ??= ref.read(appLockClockProvider)();
  }

  /// The app came back. Locks if it was away long enough.
  void returned() {
    final left = _leftAt;
    _leftAt = null;
    if (_asking || left == null || !state.enabled) return;
    final away = ref.read(appLockClockProvider)().difference(left);
    if (away >= state.timeout) state = state.copyWith(locked: true);
  }

  Future<AuthResult> _ask() async {
    _asking = true;
    try {
      return await ref.read(appAuthenticatorProvider)();
    } finally {
      _asking = false;
      _leftAt = null;
    }
  }

  /// Asks the phone, and unlocks on success. A phone with no lock set any
  /// more unlocks too, or the person would be shut out of their own data.
  Future<bool> unlock() async {
    if (_asking) return false;
    final result = await _ask();
    if (result == AuthResult.failed) return false;
    state = state.copyWith(locked: false);
    return true;
  }

  /// Turns the lock on or off. Both need the phone's unlock. Returns what
  /// happened, so the screen can explain a refusal.
  Future<AuthResult> setEnabled(bool on) async {
    final result = await _ask();
    final allowed =
        result == AuthResult.success ||
        (!on && result == AuthResult.unavailable);
    if (allowed) {
      state = state.copyWith(enabled: on, locked: false);
      await _save();
    }
    return result;
  }

  Future<void> setTimeout(Duration timeout) async {
    state = state.copyWith(timeout: timeout);
    await _save();
  }
}

final appLockProvider = NotifierProvider<AppLock, AppLockState>(AppLock.new);
