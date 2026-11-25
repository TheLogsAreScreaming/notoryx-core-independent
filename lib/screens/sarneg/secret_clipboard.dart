// The clipboard for SARNEG text: marked sensitive where the platform allows,
// and removed for real when it's cleared.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('notoryx/clipboard');

bool get _android => !kIsWeb && Platform.isAndroid;

/// Copies [text]. On Android it is marked sensitive, so the system and
/// keyboards don't show it in previews or keep it in clipboard history.
Future<void> copySecretText(String text) async {
  if (_android) {
    try {
      await _channel.invokeMethod<void>('copySensitive', text);
      return;
    } on MissingPluginException {
      // Older native build: fall through to the plain copy.
    } on PlatformException catch (e) {
      debugPrint('SARNEG: sensitive copy failed (${e.code})');
    }
  }
  await Clipboard.setData(ClipboardData(text: text));
}

/// Empties the clipboard. On Android the clip is removed, so apps offer
/// nothing to paste.
Future<void> clearClipboard() async {
  if (_android) {
    try {
      await _channel.invokeMethod<void>('clear');
      return;
    } on MissingPluginException {
      // Older native build: fall through to the plain clear.
    } on PlatformException catch (e) {
      debugPrint('SARNEG: clipboard clear failed (${e.code})');
    }
  }
  await Clipboard.setData(const ClipboardData(text: ''));
}

/// Clears the clipboard if it still holds [value].
///
/// Android 10 and later won't let an app in the background read the
/// clipboard, and that's where SARNEG text usually is a minute later (the
/// person switched apps to paste it). When it can't be read, clear it
/// anyway: leaving a code word behind is worse than dropping something
/// copied in the last minute.
Future<void> clearClipboardIfStill(String value) async {
  try {
    final now = await Clipboard.getData(Clipboard.kTextPlain);
    if (now == null || now.text == null || now.text == value) {
      await clearClipboard();
    }
  } on Exception catch (e) {
    // Never log the text itself.
    debugPrint('SARNEG: clipboard not cleared (${e.runtimeType})');
  }
}
