import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/delivery.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';

Message _message({
  MessageStatus status = MessageStatus.failed,
  int attempts = 8,
  bool? flooded,
  MessageKind kind = MessageKind.direct,
}) => Message(
  id: 1,
  radioKey: 'r',
  kind: kind,
  thread: 'd:aa',
  outgoing: true,
  body: 'hi',
  sentAt: 0,
  storedAt: 0,
  status: status,
  attempts: attempts,
  flooded: flooded,
  textType: 0,
);

Contact _contact(int pathLength) => Contact(
  radioKey: 'r',
  publicKey: 'aa',
  name: 'Ann',
  type: 1,
  flags: 0,
  outPathLength: pathLength,
  outPath: Uint8List(0),
  lastAdvert: 0,
  lastModified: 0,
);

void main() {
  test('a failed message lists likely causes and the route', () {
    final r = deliveryReport(_message(), retrying: false, contact: _contact(2));
    expect(r.headline, 'No confirmation after 8 tries');
    expect(r.details.join('\n'), contains('added you as a contact'));
    expect(r.details.last, 'Known route to Ann: 2 hops.');
  });

  test('a message the radio refused says so', () {
    final r = deliveryReport(_message(attempts: 0), retrying: false);
    expect(r.headline, 'The radio didn’t send it');
  });

  test('a flooded delivery explains the route was found again', () {
    final r = deliveryReport(
      _message(status: MessageStatus.delivered, attempts: 5, flooded: true),
      retrying: false,
      contact: _contact(pathUnknown),
    );
    expect(r.headline, 'Delivered after 5 tries');
    expect(r.details.first, contains('flood'));
    expect(r.details.last, contains('No known route'));
  });

  test('a retrying message shows progress out of the policy total', () {
    final r = deliveryReport(
      _message(status: MessageStatus.sent, attempts: 2),
      retrying: true,
    );
    expect(r.headline, 'Not confirmed yet: 2 tries so far, up to 8');
  });

  test('channel messages have no confirmation', () {
    final r = deliveryReport(
      _message(status: MessageStatus.sent, kind: MessageKind.channel),
      retrying: false,
    );
    expect(r.headline, 'Sent to the channel');
  });

  test('a direct route reads as direct', () {
    final r = deliveryReport(
      _message(status: MessageStatus.delivered, attempts: 1),
      retrying: false,
      contact: _contact(0),
    );
    expect(r.headline, 'Delivered after 1 try');
    expect(r.details, ['Known route to Ann: direct.']);
  });
}
