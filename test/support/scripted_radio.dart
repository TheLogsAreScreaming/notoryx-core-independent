import 'dart:convert';
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
    // Signing: ready for 8 KB, then a dummy signature.
    33 => [
      [19, 0, 0, 0x20, 0, 0],
    ],
    35 => [
      [20, ...List.filled(64, 0)],
    ],
    34 || 62 => [
      [0],
    ],
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
    CommandCode.deviceQuery => [
      deviceInfoFrame(maxChannels: 3, maxContacts: contactLimit),
    ],
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
    CommandCode.sendTracePath => _trace(frame),
    CommandCode.sendTelemetryRequest => _telemetry(frame),
    CommandCode.getStats => _stats(frame),
    CommandCode.runCliCommand => [
      [
        ResponseCode.cliReply,
        ...utf8.encode('> ran ${utf8.decode(frame.sublist(1))}'),
      ],
    ],
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

  /// Whether traces come back. Each hop reports 2.5 dB more than the last,
  /// starting at -5 dB, and this radio hears the last hop at 6 dB.
  bool traceReturns = true;
  final traces = <List<int>>[];

  List<List<int>> _trace(List<int> frame) {
    traces.add(frame);
    final flags = frame[9];
    final hashes = frame.sublist(10);
    final hops = hashes.length >> (flags & 3);
    return [
      [ResponseCode.sent, 0, ...frame.sublist(1, 5), ...u32(500)],
      if (traceReturns)
        [
          PushCode.traceData,
          0,
          hashes.length,
          flags,
          ...frame.sublist(1, 9),
          ...hashes,
          for (var i = 0; i < hops; i++) (-20 + 10 * i) & 0xFF,
          24,
        ],
    ];
  }

  /// The radio's own telemetry (Cayenne LPP): 4.06 V on channel 1.
  /// Noise floor answered to a stats request; null for firmware without.
  int? noiseFloor = -112;
  int statsRequests = 0;

  List<List<int>> _stats(List<int> frame) {
    statsRequests++;
    final noise = noiseFloor;
    if (noise == null) return [errorFrame(RadioErrorCode.unsupportedCommand)];
    return [
      [
        ResponseCode.stats,
        frame[1],
        ...u16(noise & 0xFFFF),
        (-80) & 0xFF,
        24,
        ...u32(30),
        ...u32(600),
      ],
    ];
  }

  List<int> selfTelemetry = [1, 116, 0x01, 0x96];

  /// Nodes' telemetry, by first key byte. Unlisted nodes don't answer.
  final nodeTelemetry = <int, List<int>>{};
  final telemetryRequests = <List<int>>[];

  List<List<int>> _telemetry(List<int> frame) {
    telemetryRequests.add(frame);
    if (frame.length == 4) {
      return [
        [
          PushCode.telemetryResponse,
          0,
          ...testKey.sublist(0, 6),
          ...selfTelemetry,
        ],
      ];
    }
    final data = nodeTelemetry[frame[4]];
    return [
      [ResponseCode.sent, 0, ...u32(0xC0), ...u32(1000)],
      if (data != null)
        [PushCode.telemetryResponse, 0, ...frame.sublist(4, 10), ...data],
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

  /// How many contacts the radio holds (even numbers only, as on the wire).
  int contactLimit = 100;

  List<List<int>> _addContact(List<int> frame) {
    // Same layout as a contact frame after the first byte.
    final entry = [ResponseCode.contact, ...frame.sublist(1)];
    final known = contacts.any((c) => _sameKey(c, entry));
    if (!known && contacts.length >= contactLimit) {
      return [errorFrame(RadioErrorCode.tableFull)];
    }
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
