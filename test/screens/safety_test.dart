import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/open_connect.dart';

import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/position.dart';
import 'package:notoryx_core/app/safety.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_notifier.dart';
import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/scripted_radio.dart';

class _Connector implements RadioConnector {
  _Connector(this.newLink);

  final FakeRadioLink Function() newLink;

  @override
  bool get supportsUsb => false;

  @override
  Stream<BleTarget> scanBluetooth({bool all = false}) => Stream.value(
    const BleTarget(deviceId: 'aa', label: 'MeshCore-Base', rssi: -60),
  );

  @override
  Future<List<UsbTarget>> listUsb() async => const [];

  @override
  Future<RadioLink> open(RadioTarget target) async => newLink();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;
  late FakeNotifier notifier;
  late FakeRadioLink link;
  late ScriptedRadio radio;
  var now = DateTime(2026, 11, 7, 9);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<List<String>> sent(WidgetTester tester) async =>
      (await tester.runAsync(
        () => (db.select(
          db.messages,
        )..where((m) => m.outgoing.equals(true))).map((m) => m.body).get(),
      ))!;

  Future<void> openSafety(WidgetTester tester) async {
    db = MeshDatabase.inMemory();
    notifier = FakeNotifier();
    now = DateTime(2026, 11, 7, 9);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          radioConnectorProvider.overrideWithValue(
            _Connector(() {
              link = FakeRadioLink();
              radio = ScriptedRadio(link);
              return link;
            }),
          ),
          messageNotifierProvider.overrideWithValue(notifier),
          foregroundCheckProvider.overrideWithValue(() => true),
          phonePositionProvider.overrideWithValue(
            () async => const LatLng(46.5, -121.25),
          ),
          safetyClockProvider.overrideWithValue(() => now),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
    await openConnect(tester);
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
    await tester.tap(find.byTooltip('Safety: SOS and check-ins'));
    await settle(tester);
    await tester.tap(find.text('Main chat'));
    await settle(tester);
    await tester.tap(find.text('#trail').last);
    await settle(tester);
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  /// Holds the SOS button for [time].
  Future<void> hold(WidgetTester tester, Duration time) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Hold for SOS')),
    );
    for (
      var t = Duration.zero;
      t < time;
      t += const Duration(milliseconds: 100)
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await gesture.up();
    await settle(tester);
  }

  /// A channel 1 message from someone else arrives.
  Future<void> hear(WidgetTester tester, String text) async {
    radio.queue.add(channelMessageFrame(text, channel: 1));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
  }

  /// Lets [time] pass on the SOS clock and the timers.
  Future<void> wait(WidgetTester tester, Duration time) async {
    now = now.add(time);
    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
  }

  testWidgets('SOS sends only when held, and repeats until answered', (
    tester,
  ) async {
    await openSafety(tester);
    // A tap or a short hold sends nothing.
    await tester.tap(find.bySemanticsLabel('Hold for SOS'));
    await settle(tester);
    expect(find.textContaining('Keep holding for 2 seconds'), findsOneWidget);
    await hold(tester, const Duration(milliseconds: 900));
    expect(await sent(tester), isEmpty);

    await hold(tester, const Duration(milliseconds: 2200));
    expect(await sent(tester), [
      'SOS - I need help. Position 46.50000,-121.25000',
    ]);
    expect(find.text('SOS active'), findsOneWidget);
    expect(find.textContaining('Sent 1 time, last at'), findsOneWidget);

    // Unanswered: sent again after 5 minutes. Chatter doesn't count.
    await wait(tester, const Duration(minutes: 3));
    expect(await sent(tester), hasLength(1));
    await hear(tester, 'Ann: anyone for lunch?');
    await wait(tester, const Duration(minutes: 2));
    expect((await sent(tester)).last, startsWith('SOS (2) - I need help.'));

    // A message that says SOS answers it, and repeats stop.
    await hear(tester, 'Ridge: saw your SOS, on our way');
    expect(
      find.text('Answered by Ridge. It no longer repeats.'),
      findsOneWidget,
    );
    await wait(tester, const Duration(minutes: 10));
    expect(await sent(tester), hasLength(2));

    // The home screen shows it too.
    await tester.pageBack();
    await settle(tester);
    expect(
      find.text("SOS answered by Ridge. Tap to send I'm safe."),
      findsOneWidget,
    );
    await tester.tap(find.text("SOS answered by Ridge. Tap to send I'm safe."));
    await settle(tester);

    await tester.tap(find.text("I'm safe"));
    await settle(tester);
    expect(
      (await sent(tester)).last,
      "I'm safe now - SOS over. Position 46.50000,-121.25000",
    );
    expect(find.text('SOS active'), findsNothing);
    expect(find.bySemanticsLabel('Hold for SOS'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('an SOS can be stopped without an all-clear', (tester) async {
    await openSafety(tester);
    await hold(tester, const Duration(milliseconds: 2200));
    await tester.tap(find.text('Stop without all-clear'));
    await settle(tester);
    await tester.tap(find.text('Keep it going'));
    await settle(tester);
    expect(find.text('SOS active'), findsOneWidget);
    await tester.tap(find.text('Stop without all-clear'));
    await settle(tester);
    await tester.tap(find.text('Stop'));
    await settle(tester);
    expect(find.text('SOS active'), findsNothing);
    expect(await sent(tester), hasLength(1), reason: 'no all-clear sent');
    await wait(tester, const Duration(minutes: 10));
    expect(await sent(tester), hasLength(1), reason: 'no repeats');
    await cleanUp(tester);
  });

  /// A direct message from Alice (key byte 1) arrives.
  Future<void> hearAlice(WidgetTester tester, String text) async {
    radio.queue.add([
      ResponseCode.contactMessageV3,
      0,
      0,
      0,
      ...List.filled(6, 1),
      0,
      0,
      ...u32(1700000100),
      ...text.codeUnits,
    ]);
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
  }

  Future<void> addAlice(WidgetTester tester) async {
    await tester.tap(find.text('Add trip contact'));
    await settle(tester);
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Alice'));
    await settle(tester);
  }

  testWidgets('a trip brief goes out and shows in the Field Log', (
    tester,
  ) async {
    await openSafety(tester);
    await addAlice(tester);
    await tester.scrollUntilVisible(
      find.text('Trip brief'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(find.text('Trip brief'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Going to'),
      'Black Rock',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Back by'),
      'Sat 6 pm',
    );
    await tester.pump();
    await tester.tap(find.text('Send to main chat and trip contacts'));
    await settle(tester);
    const text = 'Trip brief: Going to Black Rock. Back by Sat 6 pm.';
    expect(await sent(tester), [text, text]);
    await tester.pump(const Duration(seconds: 5)); // the snackbar goes
    await tester.pageBack();
    await settle(tester);

    await tester.scrollUntilVisible(
      find.text('Field Log'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(find.text('Field Log'));
    await settle(tester);
    expect(find.textContaining('Sent to Alice: $text'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a SALUTE report goes to the main chat', (tester) async {
    await openSafety(tester);
    await tester.scrollUntilVisible(
      find.text('SALUTE report'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('SALUTE report'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Size'), '4 people');
    await tester.pump();
    await tester.tap(find.text('Send to main chat and trip contacts'));
    await settle(tester);
    expect(await sent(tester), contains('SALUTE S:4 people'));
    await cleanUp(tester);
  });

  testWidgets('check-ins go to trip contacts, with who it reached', (
    tester,
  ) async {
    await openSafety(tester);
    await addAlice(tester);
    expect(find.widgetWithText(InputChip, 'Alice'), findsOneWidget);

    // Alice's radio refuses the first one: shown as missed.
    radio.refuseText = true;
    await tester.tap(find.text('At camp'));
    await settle(tester);
    // The refused one is stored too, as failed.
    expect(await sent(tester), [
      for (var i = 0; i < 2; i++)
        'Check-in: At camp. Position 46.50000,-121.25000',
    ]);
    expect(find.textContaining('Last check-in: At camp'), findsOneWidget);
    expect(
      find.bySemanticsLabel('#trail: Sent (channels don’t confirm)'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Alice: Not sent'), findsOneWidget);

    radio.refuseText = false;
    await tester.pump(const Duration(seconds: 5)); // the snackbar goes
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Send again to 1 missed'), 200);
    await tester.ensureVisible(find.text('Send again to 1 missed'));
    await settle(tester);
    await tester.tap(find.text('Send again to 1 missed'));
    await settle(tester);
    expect(await sent(tester), hasLength(3));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await settle(tester);
    expect(
      find.bySemanticsLabel('Alice: Sent, not confirmed yet'),
      findsOneWidget,
    );
    expect(find.text('Send again to 1 missed'), findsNothing);

    link.emit([
      PushCode.sendConfirmed,
      ...u32(radio.ack + radio.textAttempts.last),
      ...u32(300),
    ]);
    await settle(tester);
    expect(find.bySemanticsLabel('Alice: Reached'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a quiet trip contact is warned about once per spell', (
    tester,
  ) async {
    await openSafety(tester);
    await addAlice(tester);
    await tester.scrollUntilVisible(
      find.text('Warn me if a trip contact is quiet for'),
      200,
    );
    await tester.tap(find.text('Warn me if a trip contact is quiet for'));
    await settle(tester);
    await tester.tap(find.text('1 hour').last);
    await settle(tester);

    await wait(tester, const Duration(minutes: 30));
    expect(notifier.shown, isEmpty);
    await wait(tester, const Duration(minutes: 31));
    expect(notifier.shown.single.title, 'Alice has gone quiet');
    expect(
      notifier.shown.single.body,
      'Nothing from Alice for over 61 minutes.',
    );
    await wait(tester, const Duration(minutes: 30));
    expect(notifier.shown, hasLength(1), reason: 'once per quiet spell');

    // Hearing from her starts a new spell.
    await hearAlice(tester, "Check-in: I'm OK. Position unknown.");
    final heardAt = notifier.shown.length;
    await wait(tester, const Duration(minutes: 30));
    expect(notifier.shown, hasLength(heardAt));
    await wait(tester, const Duration(minutes: 40));
    expect(notifier.shown.last.title, 'Alice has gone quiet');
    expect(notifier.shown.last.body, startsWith('Last heard from Alice'));
    await cleanUp(tester);
  });

  testWidgets('a missed check-in reminds, then tells the chat', (tester) async {
    await openSafety(tester);
    await tester.scrollUntilVisible(find.text('Check in every'), 200);
    await tester.tap(find.text('Check in every'));
    await settle(tester);
    await tester.tap(find.text('30 minutes').last);
    await settle(tester);
    expect(find.textContaining('Next check-in due'), findsOneWidget);

    // Checking in on time pushes the deadline back.
    now = now.add(const Duration(minutes: 20));
    await tester.scrollUntilVisible(find.text("I'm OK"), -200);
    await tester.ensureVisible(find.text("I'm OK"));
    await settle(tester);
    await tester.tap(find.text("I'm OK"));
    await settle(tester);
    expect(await sent(tester), [
      "Check-in: I'm OK. Position 46.50000,-121.25000",
    ]);
    now = now.add(const Duration(minutes: 20));
    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
    expect(notifier.shown, isEmpty);

    now = now.add(const Duration(minutes: 11));
    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
    expect(notifier.shown.single.title, 'Check-in due');

    now = now.add(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
    final bodies = await sent(tester);
    expect(bodies, hasLength(2));
    expect(bodies.last, startsWith('Missed check-in (due 09:50).'));
    expect(find.textContaining('Next check-in due'), findsNothing);

    // Sent once only.
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);
    expect(await sent(tester), hasLength(2));
    await cleanUp(tester);
  });

  test('what answers an SOS', () {
    Message m(String body, MessageKind kind) => Message(
      id: 1,
      radioKey: 'r',
      kind: kind,
      thread: 't',
      outgoing: false,
      body: body,
      sentAt: 0,
      storedAt: 0,
      status: MessageStatus.received,
      attempts: 0,
      textType: 0,
    );
    expect(answersSos(m('ok', MessageKind.direct)), isTrue);
    expect(
      answersSos(m('lunch?', MessageKind.channel), myName: 'Base'),
      isFalse,
    );
    expect(answersSos(m('got your SOS', MessageKind.channel)), isTrue);
    expect(
      answersSos(m('@[Base] coming', MessageKind.channel), myName: 'Base'),
      isTrue,
    );
    expect(answersSos(m('sosig', MessageKind.channel)), isFalse);
    expect(sosText(null, send: 3), 'SOS (3) - I need help. Position unknown.');
  });

  test('message texts', () {
    expect(sosText(null), 'SOS - I need help. Position unknown.');
    expect(
      missedText(null, due: DateTime(2026, 1, 1, 7, 5)),
      'Missed check-in (due 07:05). No reply from me. Last known position unknown.',
    );
  });
}
