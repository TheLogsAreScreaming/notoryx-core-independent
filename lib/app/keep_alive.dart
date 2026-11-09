import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';

/// Keeps the app running in the background while it holds a radio, and
/// asks Android's battery saver to leave it alone. Does nothing off Android.
abstract interface class BackgroundKeeper {
  /// Starts, or updates, the ongoing "connected" notification.
  Future<void> start(String text);

  /// Lets the app be stopped in the background again.
  Future<void> stop();

  /// Whether the battery saver is set to leave the app alone.
  Future<bool> batteryUnrestricted();

  /// Asks the person to let the app run in the background.
  Future<void> requestBatteryUnrestricted();
}

/// Talks to `KeepAliveService` in the Android app.
final class AndroidBackgroundKeeper implements BackgroundKeeper {
  static const _channel = MethodChannel('notoryx/keep_alive');

  @override
  Future<void> start(String text) =>
      _channel.invokeMethod<void>('start', {'text': text});

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<bool> batteryUnrestricted() async =>
      await _channel.invokeMethod<bool>('batteryUnrestricted') ?? true;

  @override
  Future<void> requestBatteryUnrestricted() =>
      _channel.invokeMethod<void>('requestBatteryUnrestricted');
}

/// Platforms that don't stop a connected app in the background.
final class NoBackgroundKeeper implements BackgroundKeeper {
  const NoBackgroundKeeper();

  @override
  Future<void> start(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> batteryUnrestricted() async => true;

  @override
  Future<void> requestBatteryUnrestricted() async {}
}

final keepAliveProvider = Provider<BackgroundKeeper>(
  (ref) => Platform.isAndroid
      ? AndroidBackgroundKeeper()
      : const NoBackgroundKeeper(),
);

/// The notification text for [state], or null when nothing needs keeping.
String? keepAliveText(RadioConnectionState state) => switch (state) {
  Connected(:final radio) => 'Connected to ${radio.self.name}',
  Reconnecting(:final radioName) => 'Reconnecting to $radioName',
  Connecting() || Disconnected() || ViewingSaved() => null,
};

/// Holds the app in the background while a radio is connected or being
/// got back, and lets it go once the person disconnects.
final keepAliveWatcherProvider = Provider<void>((ref) {
  final keepAlive = ref.read(keepAliveProvider);
  final log = ref.read(connectionLogProvider);
  String? shown;
  void apply(RadioConnectionState state) {
    final text = keepAliveText(state);
    if (text == shown) return;
    shown = text;
    log.add(
      text == null ? 'background service: off' : 'background service: on',
    );
    final call = text == null ? keepAlive.stop() : keepAlive.start(text);
    unawaited(call.catchError((Object e) => log.add('background service: $e')));
  }

  apply(ref.read(connectionProvider));
  ref.listen(connectionProvider, (_, next) => apply(next));
});

/// Whether the battery saver may stop the app in the background, checked
/// again whenever this is refreshed.
final batteryRestrictedProvider = FutureProvider<bool>(
  (ref) async => !await ref.read(keepAliveProvider).batteryUnrestricted(),
);

/// Setting set once the person says not to ask about the battery saver.
const batteryPromptDismissedSetting = 'battery_prompt_dismissed';

/// Whether to ask about the battery saver: it's restricting the app and
/// the person hasn't said "not now".
final batteryPromptProvider = FutureProvider<bool>((ref) async {
  final store = ref.read(storeProvider);
  if (await store.setting(batteryPromptDismissedSetting) != null) return false;
  return ref.watch(batteryRestrictedProvider.future);
});
