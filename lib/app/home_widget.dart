/// Keeps the Android home-screen widget up to date.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock.dart';
import 'connection.dart';
import 'safety.dart';

/// What the widget shows.
typedef WidgetLines = ({String status, String detail});

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The widget's two lines. With the app lock on, [private] leaves out the
/// radio's name and check-in details, since a home screen is on show.
WidgetLines widgetLines(
  RadioConnectionState connection, {
  bool sosActive = false,
  DateTime? lastCheckIn,
  bool private = false,
}) {
  String named(String word, String name) => private ? word : '$word: $name';
  final status = switch (connection) {
    Connected(:final radio) => named('Connected', radio.self.name),
    Reconnecting(:final radioName) => named('Reconnecting', radioName),
    Connecting() => 'Connecting…',
    Disconnected() || ViewingSaved() => 'No radio connected',
  };
  final detail = sosActive
      ? 'SOS is active'
      : lastCheckIn == null || private
      ? ''
      : 'Last check-in ${_clock(lastCheckIn)}';
  return (status: status, detail: detail);
}

const _channel = MethodChannel('notoryx/widget');

/// Asks to open Safety when the widget is tapped.
void listenForWidgetTaps(void Function() openSafety) {
  if (!Platform.isAndroid) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'openSafety') openSafety();
  });
  _channel.invokeMethod<bool>('takeLaunch').then((opened) {
    if (opened ?? false) openSafety();
  }, onError: (Object _) {});
}

/// Sends the current lines to the widget whenever they change.
final homeWidgetSyncProvider = Provider<void>((ref) {
  if (!Platform.isAndroid) return;
  final safety = ref.watch(safetyProvider).value;
  final lines = widgetLines(
    ref.watch(connectionProvider),
    sosActive: safety?.sosActive ?? false,
    lastCheckIn: safety?.lastCheckIn,
    private: ref.watch(appLockProvider.select((l) => l.enabled)),
  );
  _channel
      .invokeMethod<void>('update', {
        'status': lines.status,
        'detail': lines.detail,
      })
      .catchError((Object e) {
        ref.read(connectionLogProvider).add('home widget: $e');
      });
});
