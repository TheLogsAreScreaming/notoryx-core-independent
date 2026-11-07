import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

/// Builds frames the way the firmware lays them out, field by field.
class _Frame {
  _Frame(int code) {
    _bytes.add(code);
  }

  final _bytes = <int>[];

  _Frame u8(int v) => this.._bytes.add(v & 0xFF);
  _Frame u16(int v) => this.._bytes.addAll([v & 0xFF, (v >> 8) & 0xFF]);
  _Frame u32(int v) {
    final d = ByteData(4)..setUint32(0, v, Endian.little);
    return this.._bytes.addAll(d.buffer.asUint8List());
  }

  _Frame i32(int v) {
    final d = ByteData(4)..setInt32(0, v, Endian.little);
    return this.._bytes.addAll(d.buffer.asUint8List());
  }

  _Frame raw(List<int> v) => this.._bytes.addAll(v);
  _Frame text(String v) => raw(utf8.encode(v));
  _Frame padded(String v, int width) {
    final encoded = utf8.encode(v);
    return raw([...encoded, ...List.filled(width - encoded.length, 0)]);
  }

  Uint8List get bytes => Uint8List.fromList(_bytes);
}

final _keyBytes = List.generate(32, (i) => 0xA0 + i);
final _key = PublicKey(_keyBytes);

void main() {
  test('ok with and without a value', () {
    expect((decodeFrame([0]) as OkReply).value, isNull);
    expect((decodeFrame(_Frame(0).u32(7).bytes) as OkReply).value, 7);
  });

  test('error codes, including unknown ones', () {
    expect((decodeFrame([1, 2]) as ErrorReply).code, RadioErrorCode.notFound);
    expect((decodeFrame([1, 99]) as ErrorReply).code, RadioErrorCode.unknown);
    expect((decodeFrame([1]) as ErrorReply).code, RadioErrorCode.unknown);
  });

  test('self info', () {
    final frame = _Frame(ResponseCode.selfInfo)
        .u8(1)
        .u8(22)
        .u8(30)
        .raw(_keyBytes)
        .i32(35227000)
        .i32(-80843000)
        .u8(1)
        .u8(2)
        .u8(0x26) // env 2, location 1, base 2
        .u8(1)
        .u32(910525)
        .u32(62500)
        .u8(7)
        .u8(5)
        .text('Base Camp')
        .bytes;
    final info = decodeFrame(frame) as SelfInfo;
    expect(info.nodeType, NodeType.chat);
    expect(info.txPowerDbm, 22);
    expect(info.maxTxPowerDbm, 30);
    expect(info.publicKey, _key);
    expect(info.latitude, closeTo(35.227, 1e-9));
    expect(info.longitude, closeTo(-80.843, 1e-9));
    expect(info.multiAcks, 1);
    expect(info.advertLocationPolicy, 2);
    expect(info.telemetryModes, (base: 2, location: 1, environment: 2));
    expect(info.manualAddContacts, isTrue);
    expect(info.frequencyMhz, 910.525);
    expect(info.bandwidthKhz, 62.5);
    expect(info.spreadingFactor, 7);
    expect(info.codingRate, 5);
    expect(info.name, 'Base Camp');
  });

  test('self info with no position', () {
    final frame = _Frame(ResponseCode.selfInfo)
        .raw([1, 22, 22])
        .raw(_keyBytes)
        .i32(0)
        .i32(0)
        .raw([0, 0, 0, 0])
        .u32(869525)
        .u32(250000)
        .raw([11, 5])
        .bytes;
    final info = decodeFrame(frame) as SelfInfo;
    expect(info.latitude, isNull);
    expect(info.longitude, isNull);
    expect(info.name, '');
  });

  test('device info, current firmware', () {
    final frame = _Frame(ResponseCode.deviceInfo)
        .u8(14)
        .u8(175) // 350 contacts
        .u8(40)
        .u32(123456)
        .padded('15 Oct 2026', 12)
        .padded('Heltec V3', 40)
        .padded('v1.18.0', 20)
        .u8(1)
        .u8(0)
        .bytes;
    final info = decodeFrame(frame) as DeviceInfo;
    expect(info.firmwareVersionCode, 14);
    expect(info.maxContacts, 350);
    expect(info.maxChannels, 40);
    expect(info.blePin, 123456);
    expect(info.buildDate, '15 Oct 2026');
    expect(info.manufacturer, 'Heltec V3');
    expect(info.firmwareVersion, 'v1.18.0');
    expect(info.clientRepeat, isTrue);
    expect(info.pathHashMode, 0);
  });

  test('device info, old firmware without the optional bytes', () {
    final old = _Frame(ResponseCode.deviceInfo)
        .u8(8)
        .u8(50)
        .u8(8)
        .u32(0)
        .padded('', 12)
        .padded('T-Echo', 40)
        .padded('v1.9.0', 20)
        .bytes;
    final info = decodeFrame(old) as DeviceInfo;
    expect(info.maxChannels, 8);
    expect(info.clientRepeat, isNull);
    expect(info.pathHashMode, isNull);

    final ancient = decodeFrame([ResponseCode.deviceInfo, 2]) as DeviceInfo;
    expect(ancient.firmwareVersionCode, 2);
    expect(ancient.maxContacts, isNull);
  });

  test('contact list start and end', () {
    expect((decodeFrame(_Frame(2).u32(42).bytes) as ContactsStart).total, 42);
    expect(
      (decodeFrame(
        _Frame(4).u32(1700000000).bytes,
      ) as ContactsEnd).newestModified,
      1700000000,
    );
  });

  test('contact with no route and no position', () {
    final frame = _Frame(ResponseCode.contact)
        .raw(_keyBytes)
        .u8(NodeType.chat.value)
        .u8(0)
        .u8(pathUnknown)
        .raw(List.filled(64, 0))
        .padded('Trail Runner', 32)
        .u32(1700000000)
        .i32(0)
        .i32(0)
        .u32(1700000050)
        .bytes;
    final contact = (decodeFrame(frame) as ContactEntry).contact;
    expect(contact.hasRoute, isFalse);
    expect(contact.hopCount, 0);
    expect(contact.route, isEmpty);
    expect(contact.latitude, isNull);
    expect(contact.name, 'Trail Runner');
  });

  test('new advert push carries a full contact', () {
    final frame = _Frame(PushCode.newAdvert)
        .raw(_keyBytes)
        .u8(NodeType.room.value)
        .u8(0)
        .u8(0) // zero-hop neighbour
        .raw(List.filled(64, 0))
        .padded('Town Room', 32)
        .u32(1)
        .i32(0)
        .i32(0)
        .u32(2)
        .bytes;
    final contact = (decodeFrame(frame) as NewAdvert).contact;
    expect(contact.type, NodeType.room);
    expect(contact.hasRoute, isTrue);
    expect(contact.hopCount, 0);
  });

  test('sent reply', () {
    final frame = _Frame(ResponseCode.sent).u8(1).u32(0xDEADBEEF).u32(9000);
    final sent = decodeFrame(frame.bytes) as SentReply;
    expect(sent.flooded, isTrue);
    expect(sent.ackCode, 0xDEADBEEF);
    expect(sent.timeoutMs, 9000);
  });

  test('send confirmed push matches the sent ack code', () {
    final frame = _Frame(PushCode.sendConfirmed).u32(0xDEADBEEF).u32(1234);
    final confirmed = decodeFrame(frame.bytes) as SendConfirmed;
    expect(confirmed.ackCode, 0xDEADBEEF);
    expect(confirmed.roundTripMs, 1234);
  });

  test('direct message, protocol v3 with SNR', () {
    final frame = _Frame(ResponseCode.contactMessageV3)
        .u8(-26) // -6.5 dB
        .raw([0, 0])
        .raw(_keyBytes.sublist(0, 6))
        .u8(0x02)
        .u8(TextType.plain.value)
        .u32(1700000000)
        .text('On my way')
        .bytes;
    final message = decodeFrame(frame) as ContactMessage;
    expect(message.snr, -6.5);
    expect(_key.startsWith(message.senderPrefix), isTrue);
    expect(message.flooded, isTrue);
    expect(message.type, TextType.plain);
    expect(message.timestamp, 1700000000);
    expect(message.text, 'On my way');
    expect(message.signerPrefix, isNull);
  });

  test('direct message, older protocol, direct route', () {
    final frame = _Frame(ResponseCode.contactMessage)
        .raw(_keyBytes.sublist(0, 6))
        .u8(pathUnknown)
        .u8(TextType.plain.value)
        .u32(5)
        .text('hi')
        .bytes;
    final message = decodeFrame(frame) as ContactMessage;
    expect(message.snr, isNull);
    expect(message.flooded, isFalse);
    expect(message.text, 'hi');
  });

  test('signed room message carries the writer prefix before the text', () {
    final frame = _Frame(ResponseCode.contactMessageV3)
        .raw([8, 0, 0])
        .raw(_keyBytes.sublist(0, 6))
        .u8(1)
        .u8(TextType.signedPlain.value)
        .u32(5)
        .raw([1, 2, 3, 4])
        .text('posted')
        .bytes;
    final message = decodeFrame(frame) as ContactMessage;
    expect(message.signerPrefix, [1, 2, 3, 4]);
    expect(message.text, 'posted');
  });

  test('channel message, v3, with sender split', () {
    final frame = _Frame(ResponseCode.channelMessageV3)
        .u8(20)
        .raw([0, 0])
        .u8(3)
        .u8(1)
        .u8(0)
        .u32(1700000000)
        .text('Ridge: meet at 10: sharp')
        .bytes;
    final message = decodeFrame(frame) as ChannelMessage;
    expect(message.channel, 3);
    expect(message.snr, 5.0);
    expect(message.senderAndBody, (sender: 'Ridge', body: 'meet at 10: sharp'));
  });

  test('channel message without a sender name', () {
    final frame = _Frame(ResponseCode.channelMessage)
        .raw([0, 1, 0])
        .u32(1)
        .text('no colon here')
        .bytes;
    final message = decodeFrame(frame) as ChannelMessage;
    expect(message.snr, isNull);
    expect(message.senderAndBody, (sender: null, body: 'no colon here'));
  });

  test('text cut mid-character by a full frame decodes without failing', () {
    final cut = utf8.encode('ok 🚀').sublist(0, 5);
    final frame = _Frame(ResponseCode.channelMessage)
        .raw([0, 1, 0])
        .u32(1)
        .raw(cut)
        .bytes;
    expect((decodeFrame(frame) as ChannelMessage).text, startsWith('ok '));
  });

  test('channel datagram', () {
    final frame = _Frame(ResponseCode.channelData)
        .u8(-8)
        .raw([0, 0])
        .u8(2)
        .u8(pathUnknown)
        .u16(0xFFFF)
        .u8(3)
        .raw([0xA1, 0xB2, 0xC3])
        .bytes;
    final data = decodeFrame(frame) as ChannelData;
    expect(data.snr, -2.0);
    expect(data.channel, 2);
    expect(data.dataType, 0xFFFF);
    expect(data.payload, [0xA1, 0xB2, 0xC3]);
  });

  test('channel datagram whose length overruns the frame is malformed', () {
    final frame = _Frame(ResponseCode.channelData)
        .raw([0, 0, 0, 1, 0xFF])
        .u16(1)
        .u8(10)
        .raw([1, 2])
        .bytes;
    expect(decodeFrame(frame), isA<MalformedFrame>());
  });

  test('channel info and empty slots', () {
    final secret = fromHex('8b3387e9c5cdea6ac9e5edbaa115cd72');
    final info = decodeFrame(
      _Frame(ResponseCode.channelInfo)
          .u8(0)
          .padded('Public', 32)
          .raw(secret)
          .bytes,
    ) as ChannelInfo;
    expect(info.name, 'Public');
    expect(info.secret, secret);
    expect(info.isEmpty, isFalse);

    final empty = decodeFrame(
      _Frame(ResponseCode.channelInfo)
          .u8(5)
          .padded('', 32)
          .raw(List.filled(16, 0))
          .bytes,
    ) as ChannelInfo;
    expect(empty.isEmpty, isTrue);
  });

  test('battery with and without storage', () {
    final full = decodeFrame(
      _Frame(12).u16(4012).u32(120).u32(1024).bytes,
    ) as BatteryAndStorage;
    expect(full.millivolts, 4012);
    expect(full.usedKb, 120);
    expect(full.totalKb, 1024);

    final short = decodeFrame(_Frame(12).u16(3700).bytes) as BatteryAndStorage;
    expect(short.usedKb, isNull);
    expect(short.totalKb, isNull);
  });

  test('current time and empty queue', () {
    expect(
      (decodeFrame(_Frame(9).u32(1700000000).bytes) as CurrentTime).unixSeconds,
      1700000000,
    );
    expect(decodeFrame([10]), isA<NoMoreMessages>());
    expect(decodeFrame([0x83]), isA<MessagesWaiting>());
    expect(decodeFrame([0x90]), isA<ContactsFull>());
    expect(decodeFrame([15]), isA<DisabledReply>());
  });

  test('key pushes', () {
    for (final code in [
      PushCode.advert,
      PushCode.pathUpdated,
      PushCode.contactDeleted,
    ]) {
      final frame = decodeFrame(_Frame(code).raw(_keyBytes).bytes);
      final key = switch (frame) {
        AdvertHeard(:final publicKey) => publicKey,
        PathUpdated(:final publicKey) => publicKey,
        ContactDeleted(:final publicKey) => publicKey,
        _ => null,
      };
      expect(key, _key, reason: 'code $code');
    }
  });

  test('login success, current and legacy servers', () {
    final current = decodeFrame(
      _Frame(PushCode.loginSuccess)
          .u8(1)
          .raw(_keyBytes.sublist(0, 6))
          .u32(1700000000)
          .u8(3)
          .u8(2)
          .bytes,
    ) as LoginSucceeded;
    expect(current.isAdmin, isTrue);
    expect(current.serverTime, 1700000000);
    expect(current.aclPermissions, 3);
    expect(current.serverFirmwareLevel, 2);

    final legacy = decodeFrame(
      _Frame(PushCode.loginSuccess).u8(0).raw(_keyBytes.sublist(0, 6)).bytes,
    ) as LoginSucceeded;
    expect(legacy.isAdmin, isFalse);
    expect(legacy.serverTime, isNull);
  });

  test('login fail and status response skip the reserved byte', () {
    final fail = decodeFrame(
      _Frame(PushCode.loginFail).u8(0).raw(_keyBytes.sublist(0, 6)).bytes,
    ) as LoginFailed;
    expect(fail.serverPrefix, _keyBytes.sublist(0, 6));

    final status = decodeFrame(
      _Frame(PushCode.statusResponse)
          .u8(0)
          .raw(_keyBytes.sublist(0, 6))
          .raw([9, 8, 7])
          .bytes,
    ) as StatusResponse;
    expect(status.serverPrefix, _keyBytes.sublist(0, 6));
    expect(status.data, [9, 8, 7]);
  });

  test('rx log', () {
    final log = decodeFrame(
      _Frame(PushCode.rxLog).u8(-40).u8(-97).raw([1, 2]).bytes,
    ) as RxLog;
    expect(log.snr, -10.0);
    expect(log.rssi, -97);
    expect(log.packet, [1, 2]);
  });

  test('empty, unknown and truncated frames never throw', () {
    expect(decodeFrame([]), isA<MalformedFrame>());
    expect((decodeFrame([0x7E, 1]) as UnknownFrame).code, 0x7E);
    expect(decodeFrame([ResponseCode.selfInfo, 1, 2]), isA<MalformedFrame>());
    expect(decodeFrame([ResponseCode.contact]), isA<MalformedFrame>());
    expect(decodeFrame([PushCode.advert, 1, 2, 3]), isA<MalformedFrame>());
    expect(decodeFrame([ResponseCode.sent, 0]), isA<MalformedFrame>());
  });

  test('auto-add config reply', () {
    final reply = decodeFrame([
      ResponseCode.autoAddConfig,
      0x16,
      4,
    ]) as AutoAddConfigReply;
    expect((reply.flags, reply.maxHops), (0x16, 4));
  });
}
