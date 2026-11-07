import 'dart:typed_data';

import 'package:notoryx_core/radio/radio.dart';

import 'fake_radio_link.dart';
import 'radio_frames.dart';

/// A scripted companion radio with a contact table, two channels and a
/// message queue.
class ScriptedRadio {
  ScriptedRadio(this.link) {
    link.onSend = _answer;
  }

  final FakeRadioLink link;
  final contacts = <List<int>>[
    contactFrame('Alice', keyByte: 1, lastModified: 10),
  ];
  final queue = <List<int>>[];

  /// Channel slots by index: name and 16-byte secret. Unlisted slots are
  /// empty. The radio has three.
  final channels = <int, (String, List<int>)>{
    0: ('Public', List.filled(16, 0x8b)),
    1: ('#trail', List.filled(16, 0x11)),
  };
  final adverts = <bool>[];

  /// The radio's advertised position, if any.
  double? latitude;
  double? longitude;

  // LoRa settings, changed by setRadioParams.
  int frequencyKhz = 910525;
  int bandwidthHz = 62500;
  int spreadingFactor = 7;
  int codingRate = 5;
  int radioParamChanges = 0;

  List<List<int>> _setRadio(List<int> frame) {
    final data = ByteData.sublistView(Uint8List.fromList(frame));
    frequencyKhz = data.getUint32(1, Endian.little);
    bandwidthHz = data.getUint32(5, Endian.little);
    spreadingFactor = frame[9];
    codingRate = frame[10];
    radioParamChanges++;
    return [okFrame()];
  }

  final getContactsSince = <int?>[];
  bool refuseText = false;

  /// Ack code for attempt 0; each attempt adds its attempt number.
  int ack = 0x1234;

  /// Whether the radio has a route to the recipient (direct) or floods.
  bool routed = true;
  int pathResets = 0;

  /// The attempt byte of every direct message sent, in order.
  final textAttempts = <int>[];

  List<List<int>> _answer(List<int> frame) => switch (frame[0]) {
    CommandCode.appStart => [
      selfInfoFrame(
        name: name,
        txPower: txPower,
        maxTxPower: 30,
        locationPolicy: locationPolicy,
        telemetry: telemetry,
        manualAdd: manualAdd,
        latitude: latitude,
        longitude: longitude,
        frequencyKhz: frequencyKhz,
        bandwidthHz: bandwidthHz,
        spreadingFactor: spreadingFactor,
        codingRate: codingRate,
      ),
    ],
    CommandCode.setRadioParams => _setRadio(frame),
    CommandCode.deviceQuery => [deviceInfoFrame(maxChannels: 3)],
    CommandCode.setDeviceTime => [okFrame()],
    CommandCode.getContacts => _contacts(frame),
    CommandCode.getChannel => [_channel(frame[1])],
    CommandCode.setChannel => _setChannel(frame),
    CommandCode.addUpdateContact => _addContact(frame),
    CommandCode.removeContact => _removeContact(frame),
    CommandCode.sendSelfAdvert => _advert(frame),
    CommandCode.syncNextMessage => [
      queue.isEmpty ? [ResponseCode.noMoreMessages] : queue.removeAt(0),
    ],
    CommandCode.sendTextMessage => _text(frame),
    CommandCode.resetPath => _resetPath(),
    CommandCode.sendChannelText => [okFrame()],
    CommandCode.setAdvertName => _setName(frame),
    CommandCode.setAdvertLatLon => _setPosition(frame),
    CommandCode.setTxPower => _setPower(frame),
    CommandCode.setOtherParams => _setOther(frame),
    CommandCode.getAutoAddConfig => [
      [ResponseCode.autoAddConfig, autoAddFlags, autoAddMaxHops],
    ],
    CommandCode.setAutoAddConfig => _setAutoAdd(frame),
    CommandCode.getBatteryAndStorage => [
      [ResponseCode.batteryAndStorage, ...u16(4012), ...u32(120), ...u32(1024)],
    ],
    CommandCode.reboot => _reboot(),
    CommandCode.sendLogin => _login(frame),
    CommandCode.sendStatusRequest => _status(frame),
    _ => [],
  };

  // Settings the radio settings screen changes.
  String name = 'Base';
  int txPower = 22;
  int locationPolicy = 0;
  int telemetry = 0;
  bool manualAdd = false;
  int autoAddFlags = 0;
  int autoAddMaxHops = 0;
  int reboots = 0;

  List<List<int>> _setName(List<int> frame) {
    name = String.fromCharCodes(frame.sublist(1));
    return [okFrame()];
  }

  List<List<int>> _setPosition(List<int> frame) {
    final data = ByteData.sublistView(Uint8List.fromList(frame));
    latitude = data.getInt32(1, Endian.little) / 1e6;
    longitude = data.getInt32(5, Endian.little) / 1e6;
    return [okFrame()];
  }

  List<List<int>> _setPower(List<int> frame) {
    final dbm = frame[1] >= 128 ? frame[1] - 256 : frame[1];
    if (dbm < -9 || dbm > 30) {
      return [errorFrame(RadioErrorCode.illegalArgument)];
    }
    txPower = dbm;
    return [okFrame()];
  }

  List<List<int>> _setOther(List<int> frame) {
    manualAdd = frame[1] == 1;
    telemetry = frame[2];
    locationPolicy = frame[3];
    return [okFrame()];
  }

  List<List<int>> _setAutoAdd(List<int> frame) {
    autoAddFlags = frame[1];
    autoAddMaxHops = frame[2];
    return [okFrame()];
  }

  /// Servers on this mesh, by the first key byte: password and status block.
  final servers = <int, ({String password, List<int> status})>{};

  /// What servers answer to console commands.
  String consoleReply = 'v1.18.0';

  List<List<int>> _login(List<int> frame) {
    final server = servers[frame[1]];
    final prefix = frame.sublist(1, 7);
    final password = String.fromCharCodes(frame.sublist(33));
    final replies = [
      [ResponseCode.sent, 0, ...u32(0xA0), ...u32(1000)],
    ];
    if (server != null && server.password == password) {
      // Admin, server time, ACL role admin (3), firmware level 2.
      replies.add([
        PushCode.loginSuccess,
        1,
        ...prefix,
        ...u32(1700000000),
        3,
        2,
      ]);
    }
    // A wrong password gets no answer, as on real servers.
    return replies;
  }

  List<List<int>> _status(List<int> frame) {
    final server = servers[frame[1]];
    return [
      [ResponseCode.sent, 0, ...u32(0xB0), ...u32(1000)],
      if (server != null)
        [PushCode.statusResponse, 0, ...frame.sublist(1, 7), ...server.status],
    ];
  }

  List<List<int>> _reboot() {
    reboots++;
    return [];
  }

  List<int> _channel(int slot) {
    if (slot >= 3) return errorFrame(RadioErrorCode.notFound);
    final (name, secret) = channels[slot] ?? ('', List.filled(16, 0));
    return [ResponseCode.channelInfo, slot, ...padded(name, 32), ...secret];
  }

  List<List<int>> _setChannel(List<int> frame) {
    final slot = frame[1];
    if (slot >= 3) return [errorFrame(RadioErrorCode.notFound)];
    final name = String.fromCharCodes(
      frame.sublist(2, 34).takeWhile((b) => b != 0),
    );
    final secret = frame.sublist(34, 50);
    if (name.isEmpty && secret.every((b) => b == 0)) {
      channels.remove(slot);
    } else {
      channels[slot] = (name, secret);
    }
    return [okFrame()];
  }

  List<List<int>> _addContact(List<int> frame) {
    // Same layout as a contact frame after the first byte.
    final entry = [ResponseCode.contact, ...frame.sublist(1)];
    contacts.removeWhere((c) => _sameKey(c, entry));
    contacts.add(entry);
    return [okFrame()];
  }

  List<List<int>> _removeContact(List<int> frame) {
    final before = contacts.length;
    contacts.removeWhere((c) => _sameKey(c, [0, ...frame.sublist(1, 33)]));
    return [
      contacts.length < before
          ? okFrame()
          : errorFrame(RadioErrorCode.notFound),
    ];
  }

  List<List<int>> _advert(List<int> frame) {
    adverts.add(frame.length > 1 && frame[1] == 1);
    return [okFrame()];
  }

  static bool _sameKey(List<int> a, List<int> b) {
    for (var i = 1; i <= 32; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<List<int>> _text(List<int> frame) {
    if (refuseText) return [errorFrame(RadioErrorCode.tableFull)];
    if (frame[1] == TextType.cliData.value) {
      // Console command: no ack; the server's reply queues as console text.
      queue.add([
        ResponseCode.contactMessageV3,
        0,
        0,
        0,
        ...frame.sublist(7, 13),
        0,
        TextType.cliData.value,
        ...u32(1700000001),
        ...consoleReply.codeUnits,
      ]);
      return [
        [ResponseCode.sent, 0, ...u32(0), ...u32(1000)],
        [PushCode.messagesWaiting],
      ];
    }
    final attempt = frame[2];
    textAttempts.add(attempt);
    return [
      [ResponseCode.sent, routed ? 0 : 1, ...u32(ack + attempt), ...u32(5000)],
    ];
  }

  List<List<int>> _resetPath() {
    routed = false;
    pathResets++;
    return [okFrame()];
  }

  List<List<int>> _contacts(List<int> frame) {
    getContactsSince.add(frame.length >= 5 ? frame[1] : null);
    return [
      [ResponseCode.contactsStart, ...u32(contacts.length)],
      ...contacts,
      [ResponseCode.endOfContacts, ...u32(contacts.length * 10)],
    ];
  }
}
