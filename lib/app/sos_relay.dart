/// SOS relay: when this radio hears a channel SOS straight from the sender
/// (no hops) and no repeater passes it on, it sends the same packet once
/// more, so it can reach a repeater the sender can't.
///
/// Off by default. A packet is only ever relayed once, and only an SOS.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../radio/protocol/packet_header.dart';
import '../radio/protocol/region_scope.dart';

/// How long to wait for a repeater to pass the SOS on before relaying.
const sosRelayWait = Duration(seconds: 8);

/// Whether [body] is an SOS this app sends ("SOS - ..." or "SOS (2) - ...").
bool isSosPost(String body) => RegExp(r'^SOS( \(\d+\))? - ').hasMatch(body);

final class _Heard {
  _Heard(this.raw, this.at);

  final Uint8List raw;
  final DateTime at;
  bool repeated = false;
  bool relayed = false;
}

/// Decides what to relay. Feed it every raw packet heard and every channel
/// SOS received; [due] says which packets to send now.
final class SosRelay {
  /// Packets heard with no hops, by `slot:timestamp`.
  final _direct = <String, _Heard>{};

  /// Payloads (hex of their hash) already seen arriving through a repeater.
  final _viaRepeater = <String>{};

  final _waiting = <String, DateTime>{};

  static String _id(Uint8List payload) =>
      sha256.convert(payload).toString().substring(0, 16);

  /// Notes a raw packet. [secrets] are the channel keys, by slot.
  void heard(Uint8List raw, Map<int, Uint8List> secrets, DateTime now) {
    final header = PacketHeader.parse(raw);
    final hash = header?.channelHash;
    if (header == null || hash == null) return;
    final payload = Uint8List.sublistView(
      raw,
      raw.length - header.payloadLength,
    );
    final id = _id(payload);
    if (header.hopCount > 0) {
      _viaRepeater.add(id);
      for (final h in _direct.values) {
        if (_id(_payloadOf(h.raw)) == id) h.repeated = true;
      }
      return;
    }
    for (final MapEntry(key: slot, value: secret) in secrets.entries) {
      if (sha256.convert(secret).bytes.first != hash) continue;
      final time = channelPostTime(payload, secret);
      if (time == null) continue;
      _direct['$slot:$time'] = _Heard(Uint8List.fromList(raw), now)
        ..repeated = _viaRepeater.contains(id);
    }
    _forgetOld(now);
  }

  /// A channel post arrived. If it's an SOS heard directly, it is queued.
  void received({
    required int slot,
    required int sentAt,
    required String body,
    required DateTime now,
  }) {
    if (!isSosPost(body)) return;
    final key = '$slot:$sentAt';
    if (_direct.containsKey(key)) _waiting[key] = now;
  }

  /// The packets to relay now. Each is returned at most once.
  List<Uint8List> due(DateTime now) {
    final out = <Uint8List>[];
    for (final MapEntry(:key, value: since) in [..._waiting.entries]) {
      if (now.difference(since) < sosRelayWait) continue;
      _waiting.remove(key);
      final h = _direct[key];
      if (h == null || h.repeated || h.relayed) continue;
      h.relayed = true;
      out.add(h.raw);
    }
    return out;
  }

  static Uint8List _payloadOf(Uint8List raw) {
    final header = PacketHeader.parse(raw)!;
    return Uint8List.sublistView(raw, raw.length - header.payloadLength);
  }

  void _forgetOld(DateTime now) {
    _direct.removeWhere(
      (_, h) => !h.relayed && now.difference(h.at) > const Duration(minutes: 5),
    );
    if (_viaRepeater.length > 500) _viaRepeater.clear();
  }
}
