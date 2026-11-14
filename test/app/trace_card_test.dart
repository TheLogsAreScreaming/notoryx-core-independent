import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/trace_card.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/l10n/l10n.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/trace_card_view.dart';

Contact _node(String name, String key, {double? lat, double? lon}) => Contact(
  radioKey: 'r',
  publicKey: key.padRight(64, '0'),
  name: name,
  type: NodeType.repeater.value,
  flags: 0,
  outPathLength: pathUnknown,
  outPath: Uint8List(64),
  lastAdvert: 0,
  lastModified: 0,
  latitude: lat,
  longitude: lon,
);

void main() {
  final contacts = [
    _node('Tower', '11', lat: 35.20, lon: -80.80),
    _node('Barn', '22'),
  ];
  // Out through Tower and Barn, back through Tower.
  final trace = TraceData(
    tag: 1,
    authCode: 0,
    hashBytes: 1,
    hashes: [0x11, 0x22, 0x11],
    snrs: [7.5, -4.25, 2],
    finalSnr: -12,
  );
  final sentAt = DateTime(2026, 11, 13, 9, 30);
  TraceCard card({double? lat = 35.22, double? lon = -80.84}) =>
      TraceCard.fromTrace(
        trace: trace,
        contacts: contacts,
        senderName: 'Base',
        targetName: 'Barn',
        sentAt: sentAt,
        returnedAt: sentAt.add(const Duration(milliseconds: 4250)),
        selfLatitude: lat,
        selfLongitude: lon,
      );

  test('stops run from this radio, through each hop, and back', () {
    final c = card();
    expect(c.stops.map((s) => s.label), [
      'Base',
      'Tower',
      'Barn',
      'Tower',
      'Base',
    ]);
    expect(c.legs, hasLength(4));
    expect(c.legs.last.snr, -12);
    expect(c.legs.map((l) => l.returning), [false, false, true, true]);
    expect(c.roundTrip, const Duration(milliseconds: 4250));
    expect(c.repeaterCount, 2);
    expect(c.weakestSnr, -12);
  });

  test('unknown hops are shown by hash and left off the sketch', () {
    final c = TraceCard.fromTrace(
      trace: TraceData(
        tag: 1,
        authCode: 0,
        hashBytes: 1,
        hashes: [0xab],
        snrs: [1],
        finalSnr: 1,
      ),
      contacts: contacts,
      senderName: 'Base',
      targetName: 'X',
      sentAt: sentAt,
      returnedAt: sentAt,
    );
    expect(c.stops[1].label, 'AB');
    expect(c.unplacedRepeaters, 1);
    expect(c.placedStops, isEmpty);
  });

  test('positions at 0,0 are treated as unknown', () {
    final c = TraceCard.fromTrace(
      trace: trace,
      contacts: [_node('Tower', '11', lat: 0, lon: 0), contacts[1]],
      senderName: 'Base',
      targetName: 'Barn',
      sentAt: sentAt,
      returnedAt: sentAt,
    );
    expect(c.unplacedRepeaters, 2);
  });

  test('a clock running backwards never gives a negative round trip', () {
    final c = TraceCard.fromTrace(
      trace: trace,
      contacts: contacts,
      senderName: 'Base',
      targetName: 'Barn',
      sentAt: sentAt,
      returnedAt: sentAt.subtract(const Duration(seconds: 1)),
    );
    expect(c.roundTrip, Duration.zero);
  });

  test('text names every leg in words and numbers', () {
    final text = card().toText(lookupAppLocalizations(const Locale('en')));
    expect(text, contains('Trace to Barn'));
    expect(text, contains('Sent by Base'));
    expect(text, contains('Round trip 4250 ms through 2 repeaters'));
    expect(text, contains('Tower → Barn: -4.3 dB (Usable)'));
    expect(text, contains('Tower → Base: -12.0 dB (Weak)'));
    expect(text, contains('Tower: 35.20000, -80.80000'));
    expect(text, contains('Base: 35.22000, -80.84000'));
  });

  test('text is translated', () {
    final text = card().toText(lookupAppLocalizations(const Locale('es')));
    expect(text, contains('Traza hasta Barn'));
    expect(text, contains('(Débil)'));
  });

  test('sketch keeps north up and fits the box', () {
    final c = card();
    final points = sketchPoints(c.placedStops, 200, 100);
    expect(points, hasLength(c.placedStops.length));
    for (final p in points) {
      expect(p.x, inInclusiveRange(0, 200));
      expect(p.y, inInclusiveRange(0, 100));
    }
    // Base (35.22 N) is north of Tower (35.20 N), so it's higher up.
    expect(points.first.y, lessThan(points[1].y));
    expect(sketchPoints(c.placedStops.take(1).toList(), 200, 100), isEmpty);
  });

  testWidgets('the card reads each leg and the sketch to a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TraceCardView(card: card(), boundaryKey: GlobalKey()),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Tower to Barn, -4.3 dB, Usable signal'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Route sketch with 2 places')),
      findsOneWidget,
    );
    expect(find.text('Round trip 4250 ms'), findsOneWidget);
    expect(find.text('2 repeaters'), findsOneWidget);
    expect(
      find.text('1 repeater has no known position and isn’t drawn.'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
