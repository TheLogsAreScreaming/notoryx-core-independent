import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

final _key = PublicKey(List.generate(32, (i) => i + 1));

String _hex(RadioCommand command) => toHex(command.encode());

void main() {
  test('app start: code, 7 reserved bytes, app name', () {
    expect(
      _hex(const AppStart(appName: 'mccli')),
      '01'
      '00000000000000'
      '6d63636c69',
    );
  });

  test('device query carries the protocol version', () {
    expect(_hex(const DeviceQuery()), '1603');
  });

  test('get contacts with and without since', () {
    expect(_hex(const GetContacts()), '04');
    expect(_hex(const GetContacts(since: 0x01020304)), '0404030201');
  });

  test('set device time is little-endian seconds', () {
    expect(_hex(const SetDeviceTime(1234567890)), '06d2029649');
  });

  test('self advert defaults to zero hop', () {
    expect(_hex(const SendSelfAdvert()), '0700');
    expect(_hex(const SendSelfAdvert(flood: true)), '0701');
  });

  test('advert name is cut to 31 bytes without splitting a character', () {
    final frame = SetAdvertName('é' * 20).encode();
    expect(frame.length, 1 + 30);
    expect(utf8.decode(frame.sublist(1)), 'é' * 15);
  });

  test('advert position is signed microdegrees', () {
    final frame = const SetAdvertPosition(
      latitude: -33.5,
      longitude: 151.25,
    ).encode();
    final data = ByteData.sublistView(frame);
    expect(frame[0], CommandCode.setAdvertLatLon);
    expect(data.getInt32(1, Endian.little), -33500000);
    expect(data.getInt32(5, Endian.little), 151250000);
  });

  test('direct message: type, attempt, timestamp, 6-byte prefix, text', () {
    final command = SendTextMessage(
      recipient: _key,
      text: 'Hi',
      timestamp: 1234567890,
      attempt: 2,
    );
    expect(
      _hex(command),
      '02'
      '00'
      '02'
      'd2029649'
      '010203040506'
      '4869',
    );
  });

  test('channel message: plain type, index, timestamp, text', () {
    const command = SendChannelText(
      channel: 1,
      text: 'Hello',
      timestamp: 1234567890,
    );
    expect(
      _hex(command),
      '03'
      '00'
      '01'
      'd2029649'
      '48656c6c6f',
    );
  });

  test('set channel pads the name to 32 bytes then adds the secret', () {
    final secret = fromHex('8b3387e9c5cdea6ac9e5edbaa115cd72');
    final frame = SetChannel(index: 0, name: 'Public', secret: secret).encode();
    expect(frame.length, 50);
    expect(frame.sublist(0, 2), [CommandCode.setChannel, 0]);
    expect(utf8.decode(frame.sublist(2, 8)), 'Public');
    expect(frame.sublist(8, 34), everyElement(0));
    expect(frame.sublist(34), secret);
  });

  test('set channel rejects a secret that is not 16 bytes', () {
    expect(
      () => SetChannel(index: 1, name: 'x', secret: Uint8List(32)),
      throwsArgumentError,
    );
  });

  test('radio params use kHz and Hz, and add repeat only when given', () {
    const params = SetRadioParams(
      frequencyMhz: 910.525,
      bandwidthKhz: 62.5,
      spreadingFactor: 7,
      codingRate: 5,
    );
    final frame = params.encode();
    final data = ByteData.sublistView(frame);
    expect(frame.length, 11);
    expect(data.getUint32(1, Endian.little), 910525);
    expect(data.getUint32(5, Endian.little), 62500);
    expect(frame.sublist(9), [7, 5]);

    const withRepeat = SetRadioParams(
      frequencyMhz: 910.525,
      bandwidthKhz: 62.5,
      spreadingFactor: 7,
      codingRate: 5,
      clientRepeat: true,
    );
    expect(withRepeat.encode().last, 1);
  });

  test('tx power is a signed byte', () {
    expect(_hex(const SetTxPower(-9)), '0cf7');
  });

  test('reboot needs the confirmation word', () {
    expect(utf8.decode(const Reboot().encode().sublist(1)), 'reboot');
  });

  test('login sends the full key then the password', () {
    final frame = SendLogin(server: _key, password: 'pw').encode();
    expect(frame[0], CommandCode.sendLogin);
    expect(frame.sublist(1, 33), _key.bytes);
    expect(utf8.decode(frame.sublist(33)), 'pw');
  });

  test('key-only commands', () {
    for (final (command, code) in [
      (RemoveContact(_key), CommandCode.removeContact),
      (ResetPath(_key), CommandCode.resetPath),
      (SendStatusRequest(_key), CommandCode.sendStatusRequest),
      (HasConnection(_key), CommandCode.hasConnection),
      (Logout(_key), CommandCode.logout),
    ]) {
      final frame = command.encode();
      expect(frame.length, 33);
      expect(frame[0], code);
      expect(frame.sublist(1), _key.bytes);
    }
  });

  test('add or update contact round-trips through the contact frame', () {
    final contact = RadioContact(
      publicKey: _key,
      type: NodeType.repeater,
      flags: 1,
      outPathLength: 0x42, // 2 hops, 2 bytes each
      outPath: [0xAA, 0xBB, 0xCC, 0xDD],
      name: 'Ridge RPT',
      lastAdvert: 1700000000,
      latitude: 35.25,
      longitude: -80.5,
      lastModified: 1700000100,
    );
    final command = AddOrUpdateContact(contact).encode();
    expect(command.length, 148);

    // The radio's contact frame has the same layout after the first byte.
    final frame = Uint8List.fromList([
      ResponseCode.contact,
      ...command.skip(1),
    ]);
    final decoded = (decodeFrame(frame) as ContactEntry).contact;
    expect(decoded.publicKey, _key);
    expect(decoded.type, NodeType.repeater);
    expect(decoded.hopCount, 2);
    expect(decoded.bytesPerHop, 2);
    expect(decoded.route, [0xAA, 0xBB, 0xCC, 0xDD]);
    expect(decoded.name, 'Ridge RPT');
    expect(decoded.latitude, 35.25);
    expect(decoded.longitude, -80.5);
    expect(decoded.lastModified, 1700000100);
  });

  test('frames over the size limit are refused', () {
    final command = SendChannelText(channel: 0, text: 'x' * 200, timestamp: 0);
    expect(command.encode, throwsArgumentError);
  });
}
