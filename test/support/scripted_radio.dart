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
    CommandCode.getChannel => [
      switch (frame[1]) {
        0 => channelInfoFrame(0, 'Public'),
        1 => channelInfoFrame(1, '#trail'),
        _ => channelInfoFrame(frame[1], ''),
      },
    ],
    CommandCode.syncNextMessage => [
      queue.isEmpty ? [ResponseCode.noMoreMessages] : queue.removeAt(0),
    ],
    CommandCode.sendTextMessage => _text(frame),
    CommandCode.resetPath => _resetPath(),
    CommandCode.sendChannelText => [okFrame()],
    _ => [],
  };

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
