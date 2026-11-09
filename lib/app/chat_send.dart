/// Sending to a conversation named by its thread id, and forwarding.
library;

import 'dart:convert';

import '../data/data.dart';
import '../radio/protocol/region_scope.dart';
import '../radio/radio.dart';
import 'connection.dart';
import 'region_tag.dart';

/// Sends [text] to [thread] (`c:slot` or `d:key`). A channel post uses your
/// region setting, as a typed post does.
Future<void> sendToThread(
  Connected connection,
  MeshStore store,
  String thread,
  String text,
) async {
  final target = thread.substring(2);
  if (thread.startsWith('c:')) {
    final region = await store.setting(regionSendSetting);
    await connection.sync.sendChannel(
      int.parse(target),
      text,
      region: cleanRegionName(region),
    );
  } else {
    await connection.sync.sendDirect(PublicKey.fromHex(target), text);
  }
}

/// [body] from [sender] as a forward, cut to fit one message.
String forwardText(String sender, String body) {
  final whole = 'Fwd $sender: $body';
  if (utf8.encode(whole).length <= maxDirectTextBytes) return whole;
  const mark = '…';
  final room = maxDirectTextBytes - utf8.encode(mark).length;
  final out = StringBuffer();
  var used = 0;
  // By whole characters, so an emoji is never cut in half.
  for (final rune in whole.runes) {
    final char = String.fromCharCode(rune);
    used += utf8.encode(char).length;
    if (used > room) break;
    out.write(char);
  }
  return '$out$mark';
}
