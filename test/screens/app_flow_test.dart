import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/open_connect.dart';

import 'package:notoryx_core/app/channel_directory.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/keep_alive.dart';
import 'package:notoryx_core/app/mesh_links.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
import 'package:notoryx_core/screens/map_tab.dart';
import 'package:notoryx_core/presets/area_presets_provider.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/scripted_radio.dart';

class _FakeConnector implements RadioConnector {
  _FakeConnector(this.newLink);

  /// Makes the link each connection gets, like a radio answering again.
  final FakeRadioLink Function() newLink;
  bool failOpen = false;
  final opened = <RadioTarget>[];

  @override
  bool get supportsUsb => false;

  bool? lastScanAll;

  @override
  Stream<BleTarget> scanBluetooth({bool all = false}) {
    lastScanAll = all;
    return Stream.fromIterable([
      const BleTarget(deviceId: 'aa', label: 'MeshCore-Base', rssi: -60),
      if (all)
        const BleTarget(
          deviceId: 'bb',
          label: 'Headphones',
          rssi: -40,
          isMeshCore: false,
        ),
    ]);
  }

  @override
  Future<List<UsbTarget>> listUsb() async => const [];

  @override
  Future<RadioLink> open(RadioTarget target) async {
    opened.add(target);
    if (failOpen) throw const LinkClosedException('radio out of range');
    return newLink();
  }
}

class _FakeBackgroundKeeper implements BackgroundKeeper {
  final calls = <String>[];
  bool restricted = false;
  int requests = 0;

  @override
  Future<void> start(String text) async => calls.add(text);

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<bool> batteryUnrestricted() async => !restricted;

  @override
  Future<void> requestBatteryUnrestricted() async => requests++;
}

class _FakeNotifier implements MessageNotifier {
  final shown = <({String title, String body, ChatLink chat})>[];
  void Function(ChatLink chat)? onOpen;

  @override
  Future<ChatLink?> init(void Function(ChatLink chat) onOpen) async {
    this.onOpen = onOpen;
    return null;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required ChatLink chat,
  }) async => shown.add((title: title, body: body, chat: chat));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeRadioLink link;
  late ScriptedRadio radio;
  late _FakeConnector connector;
  late MeshDatabase db;
  late _FakeNotifier notifier;
  late _FakeBackgroundKeeper keepAlive;

  /// Adjusts each scripted radio as it's created.
  void Function(ScriptedRadio radio)? radioSetup;
  var inFront = true;

  setUp(() {
    radioSetup = null;
    connector = _FakeConnector(() {
      link = FakeRadioLink();
      radio = ScriptedRadio(link);
      radioSetup?.call(radio);
      return link;
    });
    db = MeshDatabase.inMemory();
    notifier = _FakeNotifier();
    keepAlive = _FakeBackgroundKeeper();
    inFront = true;
  });

  // Database and fake-radio work runs on real async, outside the test's fake
  // clock, so alternate real waits with frames. Spinners never settle, so
  // this pumps a fixed number of times instead of pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    // Channel and contact changes take several radio round trips plus a
    // re-download, so give them enough real time even on a busy machine.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          radioConnectorProvider.overrideWithValue(connector),
          messageNotifierProvider.overrideWithValue(notifier),
          foregroundCheckProvider.overrideWithValue(() => inFront),
          reconnectDelaysProvider.overrideWithValue(const [
            Duration(milliseconds: 100),
          ]),
          areaPresetsFetchProvider.overrideWithValue(() async => null),
          keepAliveProvider.overrideWithValue(keepAlive),
          mapTilesProvider.overrideWithValue(null),
          phonePositionProvider.overrideWithValue(
            () async => const LatLng(46.5, -121.25),
          ),
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> connect(WidgetTester tester) async {
    await pumpApp(tester);
    await openConnect(tester);
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
  }

  // Unmounting tears the connection down; let that finish on both clocks
  // before closing the database, or the close waits on work that can't run.
  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('connect over Bluetooth, open a channel and send', (
    tester,
  ) async {
    await pumpApp(tester);
    await openConnect(tester);
    expect(find.text('Connect a radio'), findsOneWidget);
    expect(find.text('MeshCore-Base'), findsOneWidget);

    await openConnect(tester);
    await tester.tap(find.text('MeshCore-Base'));
    await settle(tester);
    expect(
      find.text('Base'),
      findsOneWidget,
      reason: 'radio name in the app bar',
    );
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('#trail'), findsOneWidget);

    await tester.tap(find.text('#trail'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'heading down');
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);

    expect(find.text('heading down'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'sent tick');
    expect(link.sent.last[0], CommandCode.sendChannelText);
    await cleanUp(tester);
  });

  testWidgets('show all lists other devices after MeshCore radios', (
    tester,
  ) async {
    await pumpApp(tester);
    await openConnect(tester);
    expect(find.text('Headphones'), findsNothing);
    await tester.tap(find.text('Show all Bluetooth devices'));
    await settle(tester);
    expect(connector.lastScanAll, isTrue);
    final radio = tester.getTopLeft(find.text('MeshCore-Base')).dy;
    final other = tester.getTopLeft(find.text('Headphones')).dy;
    expect(
      radio,
      lessThan(other),
      reason: 'radios first despite weaker signal',
    );
    await cleanUp(tester);
  });

  testWidgets('contacts tab lists the radio contacts and opens a chat', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Person · no route yet'), findsOneWidget);

    await tester.tap(find.text('Alice'));
    await settle(tester);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Alice'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a refused direct message can be sent again', (tester) async {
    await connect(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    await tester.tap(find.text('Alice'));
    await settle(tester);
    expect(
      find.text(
        'Direct messages only arrive if Alice has added you as a contact.',
      ),
      findsOneWidget,
    );

    radio.refuseText = true;
    await tester.enterText(find.byType(TextField), 'ping');
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.longPress(find.text('ping'));
    await settle(tester);
    await tester.tap(find.text('Delivery details'));
    await settle(tester);
    expect(find.text('The radio didn\u2019t send it'), findsOneWidget);
    expect(find.text('Reset route'), findsNothing, reason: 'no route yet');
    await tester.tap(find.text('Close'));
    await settle(tester);

    radio.refuseText = false;
    await tester.longPress(find.text('ping'));
    await settle(tester);
    await tester.tap(find.text('Send again'));
    await settle(tester);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(radio.textAttempts, [0]);
    await cleanUp(tester);
  });

  testWidgets('new messages show unread badges until the chat is opened', (
    tester,
  ) async {
    await connect(tester);
    radio.queue.addAll([
      channelMessageFrame('Ridge: one', channel: 1),
      channelMessageFrame('Ridge: two', channel: 1),
    ]);
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);

    final trail = find.ancestor(
      of: find.text('#trail'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: trail, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('2')),
      findsOneWidget,
      reason: 'total on the Chats tab',
    );

    await tester.tap(find.text('#trail'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect(find.descendant(of: trail, matching: find.text('2')), findsNothing);
    await cleanUp(tester);
  });

  testWidgets('a quick message sends in one tap, and drafts are kept', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.text('#trail'));
    await settle(tester);

    await tester.tap(find.byTooltip('Quick messages'));
    await settle(tester);
    await tester.tap(find.text('On my way'));
    await settle(tester);
    expect(find.text('On my way'), findsOneWidget, reason: 'the sent bubble');

    // "Change before sending" puts it in the box instead.
    await tester.tap(find.byTooltip('Quick messages'));
    await settle(tester);
    await tester.tap(find.byTooltip('Change before sending').at(2));
    await settle(tester);
    final box = find.byType(TextField);
    expect(tester.widget<TextField>(box).controller!.text, 'Arrived safe');

    // Leaving keeps it as a draft, shown in the chat list.
    await tester.enterText(box, 'Arrived safe at the hut');
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Draft: Arrived safe at the hut'), findsOneWidget);

    await tester.tap(find.text('#trail'));
    await settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Arrived safe at the hut',
    );

    // Sending clears it.
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining('Draft:'), findsNothing);
    await cleanUp(tester);
  });

  testWidgets('holding a message reacts to it or replies to it', (
    tester,
  ) async {
    await connect(tester);
    radio.queue.add(
      channelMessageFrame('Ridge: lunch at the hut?', channel: 1),
    );
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
    await tester.tap(find.text('#trail'));
    await settle(tester);

    await tester.longPress(find.text('lunch at the hut?'));
    await settle(tester);
    await tester.tap(find.byTooltip('React 👍'));
    await settle(tester);
    expect(
      find.text('👍 re "lunch at the hut?"'),
      findsNothing,
      reason: 'shown on the message, not as a bubble',
    );
    expect(find.bySemanticsLabel(RegExp('👍 1: Base')), findsOneWidget);

    await tester.longPress(find.text('lunch at the hut?'));
    await settle(tester);
    await tester.tap(find.text('Reply'));
    await settle(tester);
    expect(find.text('Replying to Ridge'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'yes please');
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
    expect(find.text('Replying to Ridge'), findsNothing);
    expect(find.text('yes please'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('In reply to Ridge: lunch at the hut')),
      findsOneWidget,
    );
    await cleanUp(tester);
  });

  testWidgets('blocking hides a sender, and mentions get through mute', (
    tester,
  ) async {
    await connect(tester);
    radio.queue.addAll([
      channelMessageFrame('Spammy: buy now', channel: 1),
      channelMessageFrame('Ridge: summit at noon', channel: 1),
    ]);
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
    await tester.tap(find.text('#trail'));
    await settle(tester);

    await tester.longPress(find.text('buy now'));
    await settle(tester);
    await tester.tap(find.text('Block Spammy'));
    await settle(tester);
    expect(find.text('buy now'), findsNothing);
    expect(find.text('summit at noon'), findsOneWidget);

    // Muted, and not in front: a blocked sender doesn't notify, nor does
    // chatter, but a mention does.
    await tester.tap(find.byTooltip('Mute notifications'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    final before = notifier.shown.length;
    radio.queue.addAll([
      channelMessageFrame('Spammy: still here', channel: 1),
      channelMessageFrame('Ridge: lunch?', channel: 1),
      channelMessageFrame('Ann: @[Base] are you coming?', channel: 1),
    ]);
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
    expect(notifier.shown.length, before + 1);
    expect(notifier.shown.last.title, '#trail: mentioned you');

    await tester.tap(find.text('#trail'));
    await settle(tester);
    expect(find.text('still here'), findsNothing);
    expect(find.text('Mentions you'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a message notifies unless its chat is open or muted', (
    tester,
  ) async {
    await connect(tester);
    radio.queue.add(channelMessageFrame('Ridge: summit at noon', channel: 1));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
    expect(notifier.shown.single.title, '#trail');
    expect(notifier.shown.single.body, 'Ridge: summit at noon');

    // Open the chat: messages there don't notify while it's in front.
    await tester.tap(find.text('#trail'));
    await settle(tester);
    radio.queue.add(channelMessageFrame('Ridge: on my way', channel: 1));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
    expect(notifier.shown, hasLength(1));

    // Mute it, go back: still no notification.
    await tester.tap(find.byTooltip('Mute notifications'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    radio.queue.add(channelMessageFrame('Ridge: muted', channel: 1));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
    expect(notifier.shown, hasLength(1));
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('#trail'),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.notifications_off_outlined),
      ),
      findsOneWidget,
    );
    await cleanUp(tester);
  });

  testWidgets('the open chat notifies when the app is in the background', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.text('#trail'));
    await settle(tester);
    inFront = false;
    radio.queue.add(channelMessageFrame('Ridge: ping', channel: 1));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
    expect(notifier.shown.single.body, 'Ridge: ping');
    await cleanUp(tester);
  });

  testWidgets('tapping a notification opens its chat', (tester) async {
    await connect(tester);
    notifier.onOpen!((
      thread: Threads.channel(1),
      title: '#trail',
      isChannel: true,
    ));
    await settle(tester);
    expect(find.widgetWithText(AppBar, '#trail'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('join a hashtag channel from the + button', (tester) async {
    await connect(tester);
    await tester.tap(find.byTooltip('Add a channel'));
    await settle(tester);
    await tester.tap(find.text('Join a #hashtag channel'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Hiking');
    await tester.tap(find.text('Join'));
    await settle(tester);

    expect(find.text('#hiking'), findsOneWidget);
    expect(radio.channels[2]!.$2, hashtagSecret('#hiking'));
    await cleanUp(tester);
  });

  testWidgets('leave a channel from its hold menu', (tester) async {
    await connect(tester);
    await tester.longPress(find.text('#trail'));
    await settle(tester);
    await tester.tap(find.text('Leave channel'));
    await settle(tester);
    await tester.tap(find.text('Leave'));
    await settle(tester);
    expect(find.text('#trail'), findsNothing);
    expect(radio.channels.containsKey(1), isFalse);
    await cleanUp(tester);
  });

  testWidgets('add a contact from a pasted link', (tester) async {
    await connect(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    await tester.tap(find.byTooltip('Add or share contacts'));
    await settle(tester);
    await tester.tap(find.text('Add from a link'));
    await settle(tester);
    final link = ContactLink(
      name: 'Dana',
      publicKey: PublicKey(List.filled(32, 4)),
      type: NodeType.chat,
    );
    await tester.enterText(find.byType(TextField), link.url);
    await tester.tap(find.text('Add'));
    await settle(tester);
    expect(find.text('Dana'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a node heard nearby can be added', (tester) async {
    await connect(tester);
    link.emit(contactFrame('Eve', keyByte: 5)..[0] = PushCode.newAdvert);
    await settle(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    expect(find.text('Heard nearby, not added'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await settle(tester);
    expect(find.text('Heard nearby, not added'), findsNothing);
    expect(find.text('Eve'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a full contact table offers to swap out the oldest', (
    tester,
  ) async {
    radioSetup = (r) => r
      ..contactLimit = 2
      ..contacts.add(
        contactFrame('Tom', keyByte: 9, lastModified: 11, lastAdvert: 5),
      );
    await connect(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    expect(find.text('2 of 2 contacts'), findsOneWidget);
    expect(
      find.text('Full: the radio won’t add new nodes it hears.'),
      findsOneWidget,
    );

    link.emit(contactFrame('Eve', keyByte: 5)..[0] = PushCode.newAdvert);
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await settle(tester);
    expect(find.text('Contacts are full'), findsOneWidget);
    // Alice was never heard, so she goes before Tom.
    expect(find.textContaining('remove Alice (never heard)'), findsOneWidget);
    await tester.tap(find.text('Swap'));
    await settle(tester);
    expect(find.text('Removed Alice and added Eve'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Tom'), findsOneWidget);
    expect(find.text('Eve'), findsOneWidget);

    // Make room: pick and remove (once the snackbar has gone).
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await tester.tap(find.text('Make room'));
    await settle(tester);
    expect(find.text('Make room for contacts'), findsOneWidget);
    await tester.tap(find.text('Pick oldest 10'));
    await settle(tester);
    expect(find.text('After removing: 0 of 2 contacts'), findsOneWidget);
    await tester.tap(find.text('Remove 2'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await settle(tester);
    expect(find.text('Removed 2.'), findsOneWidget);
    expect(find.text('Nothing to remove.'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('favourites are starred and listed first', (tester) async {
    radioSetup = (r) =>
        r.contacts.add(contactFrame('Zed', keyByte: 9, lastModified: 11));
    await connect(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    await tester.longPress(find.text('Zed'));
    await settle(tester);
    await tester.tap(find.text('Add to favourites'));
    await settle(tester);

    expect(find.byIcon(Icons.star), findsOneWidget);
    final zed = tester.getTopLeft(find.text('Zed')).dy;
    final alice = tester.getTopLeft(find.text('Alice')).dy;
    expect(zed, lessThan(alice));
    await cleanUp(tester);
  });

  testWidgets('share my contact shows a QR code and copies the link', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await connect(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    await tester.tap(find.byTooltip('Add or share contacts'));
    await settle(tester);
    await tester.tap(find.text('Share my contact'));
    await settle(tester);
    expect(find.bySemanticsLabel('QR code for My contact'), findsOneWidget);
    await tester.tap(find.text('Copy link'));
    await settle(tester);
    final parsed = MeshLink.parse(copied!) as ContactLink;
    expect(parsed.name, 'Base');
    await cleanUp(tester);
  });

  testWidgets('a repeater: log in, get its status, use the console', (
    tester,
  ) async {
    radioSetup = (r) => r
      ..servers[0x42] = (password: 'secret', status: repeaterStatusBlock())
      ..contacts.add(
        contactFrame(
          'Hill RPT',
          keyByte: 0x42,
          type: NodeType.repeater,
          lastModified: 11,
        ),
      );
    await connect(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);
    await tester.tap(find.text('Hill RPT'));
    await settle(tester);

    expect(find.widgetWithText(AppBar, 'Hill RPT'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await settle(tester);
    expect(find.text('Logged in as Admin'), findsOneWidget);

    await tester.tap(find.text('Get status'));
    await settle(tester);
    expect(find.text('4.10 V'), findsOneWidget);
    expect(find.text('1 d 1 h'), findsOneWidget, reason: 'up time');

    await tester.scrollUntilVisible(find.byTooltip('Send command'), 200);
    await tester.enterText(find.byType(TextField).last, 'ver');
    await tester.tap(find.byTooltip('Send command'));
    await settle(tester);
    expect(find.text('> ver'), findsOneWidget);
    expect(find.text('v1.18.0'), findsOneWidget);

    radio.consoleReply = '42AABBCC:90:-22';
    await tester.scrollUntilVisible(
      find.text('Neighbors'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Neighbors'));
    await settle(tester);
    expect(find.text('> neighbors'), findsOneWidget);
    expect(find.textContaining('-5.5 dB'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Ping'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ping'));
    await settle(tester);
    expect(find.textContaining('It heard you at'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('the radio command line runs commands and hides passwords', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.byTooltip('Radio settings'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Command line'), 200);
    await tester.ensureVisible(find.text('Command line'));
    await settle(tester);
    await tester.tap(find.text('Command line'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'get name');
    await tester.tap(find.byTooltip('Run command'));
    await settle(tester);
    expect(find.text('> ran get name'), findsOneWidget);

    await tester.tap(find.byTooltip('Wi-Fi setup'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Camp');
    await tester.enterText(find.byType(TextField).at(2), 'hunter2');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('> set wifi.pwd ••••••'), findsOneWidget);
    expect(find.textContaining('> ran set wifi.pwd hunter2'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('search finds a message and opens its chat', (tester) async {
    await connect(tester);
    radio.queue.add(channelMessageFrame('Ridge: summit at noon', channel: 1));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);

    await tester.tap(find.byTooltip('Search messages'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'summit');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('#trail'), findsOneWidget);

    await tester.tap(find.text('#trail'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, '#trail'), findsOneWidget);
    expect(find.text('summit at noon'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a failed connection shows why and stays on the connect screen', (
    tester,
  ) async {
    connector.failOpen = true;
    await connect(tester);
    expect(
      find.text('The connection closed before setup finished.'),
      findsOneWidget,
    );
    expect(find.text('Connect a radio'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a dropped radio reconnects while the chats stay open', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.text('Public'));
    await settle(tester);
    final firstLink = link;

    connector.failOpen = true;
    firstLink.drop();
    await settle(tester);
    expect(
      find.widgetWithText(AppBar, 'Public'),
      findsOneWidget,
      reason: 'the conversation stays open',
    );
    expect(find.text('Waiting for the radio to reconnect'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining('Reconnecting to the radio'), findsOneWidget);
    expect(
      find.text('The connection closed before setup finished.'),
      findsOneWidget,
    );

    connector.failOpen = false;
    await tester.tap(find.text('Try now'));
    await settle(tester);
    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(link, isNot(same(firstLink)));
    expect(find.text('Public'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('the app reconnects to the last radio at launch', (tester) async {
    await connect(tester);
    await cleanUp(tester);

    // A fresh start with the same database.
    final opensBefore = connector.opened.length;
    db = MeshDatabase.inMemory();
    await tester.runAsync(() async {
      final store = MeshStore(db);
      final self = decodeFrame(selfInfoFrame(name: 'Base')) as SelfInfo;
      await store.rememberRadio(self);
      await store.saveSetting(
        ConnectionController.lastRadioSetting,
        '{"target":{"kind":"ble","id":"aa","label":"MeshCore-Base"},'
        '"radioKey":"${self.publicKey.hex}","radioName":"Base",'
        '"autoConnect":true}',
      );
    });
    await pumpApp(tester);
    await settle(tester);

    expect(find.text('Connect a radio'), findsNothing);
    expect(find.text('Base'), findsOneWidget);
    expect(connector.opened.length, opensBefore + 1);
    expect((connector.opened.last as BleTarget).deviceId, 'aa');
    await cleanUp(tester);
  });

  testWidgets('disconnecting on purpose stops reconnecting, even at launch', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.byTooltip('Disconnect'));
    await settle(tester);
    expect(find.textContaining('No radio connected'), findsOneWidget);

    final saved = await tester.runAsync(
      () => MeshStore(db).setting(ConnectionController.lastRadioSetting),
    );
    expect(saved, contains('"autoConnect":false'));

    final opens = connector.opened.length;
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await pumpApp(tester);
    await settle(tester);
    expect(find.textContaining('No radio connected'), findsOneWidget);
    expect(connector.opened.length, opens, reason: 'no automatic connect');
    await cleanUp(tester);
  });

  testWidgets('the full app shows with no radio ever connected', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.textContaining('No radio yet'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.byTooltip('Radio settings'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('saved chats open with no radio, and lead back to connecting', (
    tester,
  ) async {
    await connect(tester);
    await tester.tap(find.byTooltip('Disconnect'));
    await settle(tester);
    final opens = connector.opened.length;

    expect(find.textContaining('No radio connected'), findsOneWidget);
    expect(find.byTooltip('Disconnect'), findsNothing);
    expect(find.text('Chats'), findsOneWidget);
    expect(connector.opened.length, opens, reason: 'nothing connects');

    await tester.tap(find.text('Connect'));
    await settle(tester);
    expect(find.text('Connect a radio'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('the app stays alive in the background while connected', (
    tester,
  ) async {
    await connect(tester);
    expect(keepAlive.calls, hasLength(1));
    expect(keepAlive.calls.single, startsWith('Connected to '));

    await tester.tap(find.byTooltip('Disconnect'));
    await settle(tester);
    expect(keepAlive.calls.last, 'stop');
    await cleanUp(tester);
  });

  testWidgets('asks about the battery saver until told not now', (
    tester,
  ) async {
    keepAlive.restricted = true;
    await connect(tester);
    expect(find.textContaining('Battery saver can drop'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await settle(tester);
    expect(keepAlive.requests, 1);

    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(find.textContaining('Battery saver can drop'), findsNothing);
    final saved = await tester.runAsync(
      () => MeshStore(db).setting(batteryPromptDismissedSetting),
    );
    expect(saved, isNotNull);
    await cleanUp(tester);
  });

  testWidgets('find channels shows what is heard on air, and joins', (
    tester,
  ) async {
    await connect(tester);
    void hear(int code) => link.emit([
      PushCode.rxLog,
      24,
      -90 & 0xFF,
      (PayloadKind.groupText.value << 2) | 1,
      0,
      code,
      1,
      2,
    ]);
    hear(hashtagCode('#hiking'));
    hear(hashtagCode('#hiking'));
    // A code no listed name has.
    var unknown = 0;
    while ({
      for (final g in channelDirectory) ...g.names.map(hashtagCode),
      for (final c in radio.channels.values)
        channelCode(Uint8List.fromList(c.$2)),
    }.contains(unknown)) {
      unknown++;
    }
    hear(unknown);
    await settle(tester);

    await tester.tap(find.byTooltip('Add a channel'));
    await settle(tester);
    await tester.tap(find.text('Find channels'));
    await settle(tester);
    expect(find.textContaining('Probably heard on air: 2×'), findsWidgets);
    expect(
      find.text('Unnamed channel (code ${codeLabel(unknown)})'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Join #hiking').first);
    await settle(tester);
    expect(find.text('Joined #hiking'), findsOneWidget);
    expect(radio.channels.values.map((c) => c.$1), contains('#hiking'));
    await cleanUp(tester);
  });

  testWidgets('share a position or a contact, and open what others share', (
    tester,
  ) async {
    radioSetup = (r) =>
        r.contacts.add(contactFrame('Zed', keyByte: 9, lastModified: 11));
    await connect(tester);
    await tester.tap(find.text('#trail'));
    await settle(tester);

    await tester.tap(find.byTooltip('Share position or contact'));
    await settle(tester);
    await tester.tap(find.text('My position'));
    await settle(tester);
    final box = find.byType(TextField);
    expect(
      tester.widget<TextField>(box).controller!.text,
      '📍 46.50000,-121.25000',
      reason: 'put in the box to check before sending',
    );
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
    expect(find.text('Show on map'), findsOneWidget);
    await tester.tap(find.text('Show on map'));
    await settle(tester);
    expect(find.text('46.50000, -121.25000'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    // A contact shared by someone else can be added in one tap.
    final shared = ContactLink(
      name: 'Eve',
      publicKey: PublicKey(List.filled(32, 5)),
      type: NodeType.chat,
    ).url;
    radio.queue.add(channelMessageFrame('Ridge: meet $shared', channel: 1));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);
    await tester.tap(find.text('Add Eve'));
    await settle(tester);
    expect(find.text('Added Eve'), findsOneWidget);
    expect(
      radio.contacts.any((c) => c[1] == 5),
      isTrue,
      reason: 'the radio has Eve now',
    );
    await cleanUp(tester);
  });

  testWidgets('packets heard show in the packet log', (tester) async {
    await connect(tester);
    link.emit([
      PushCode.rxLog,
      24, // 6 dB
      -90 & 0xFF,
      (PayloadKind.groupText.value << 2) | 1,
      1, 0x11,
      0x9c, 1, 2,
    ]);
    await settle(tester);
    await tester.tap(find.byTooltip('Connection log'));
    await settle(tester);
    await tester.tap(find.byTooltip('Packets heard'));
    await settle(tester);
    expect(find.text('Packets heard (1)'), findsOneWidget);
    expect(find.text('Channel message'), findsOneWidget);
    expect(find.textContaining('via 11'), findsOneWidget);
    expect(find.textContaining('SNR 6.0 dB · RSSI -90 dBm'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('a message arriving shows in the chat list', (tester) async {
    await connect(tester);
    radio.queue.add(channelMessageFrame('Ridge: summit at noon'));
    link.emit([PushCode.messagesWaiting]);
    await settle(tester);

    expect(find.text('Ridge: summit at noon'), findsOneWidget);
    await cleanUp(tester);
  });
}
