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
    CommandCode.appStart => [selfInfoFrame(name: 'Base')],
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
    _ => [],
  };

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
