/// Speaking a message with the device's own text-to-speech. Nothing leaves
/// the device.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/l10n.dart';

/// Says some text out loud. Replaces anything already being read.
typedef Speaker = Future<void> Function(String text);

/// What to read for a message from [sender].
String readAloudText(
  String sender,
  String body, {
  required bool mine,
  AppLocalizations? l10n,
}) => mine
    ? l10n?.youSaid(body) ?? 'You said: $body'
    : l10n?.senderSays(sender, body) ?? '$sender says: $body';

final speakerProvider = Provider<Speaker>((ref) {
  final tts = FlutterTts();
  return (text) async {
    await tts.stop();
    await tts.speak(text);
  };
});
