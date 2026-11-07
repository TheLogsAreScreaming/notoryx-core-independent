import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/mesh_links.dart';
import 'package:notoryx_core/app/notifications.dart';
import 'package:notoryx_core/app/radio_connector.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/main.dart';
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
        ],
        child: const NotoryxApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> connect(WidgetTester tester) async {
    await pumpApp(tester);
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
    expect(find.text('Connect a radio'), findsOneWidget);
    expect(find.text('MeshCore-Base'), findsOneWidget);

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

  testWidgets('share my contact copies a link', (tester) async {
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
    final parsed = MeshLink.parse(copied!) as ContactLink;
    expect(parsed.name, 'Base');
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
    expect(find.text('Connect a radio'), findsOneWidget);

    final saved = await tester.runAsync(
      () => MeshStore(db).setting(ConnectionController.lastRadioSetting),
    );
    expect(saved, contains('"autoConnect":false'));

    final opens = connector.opened.length;
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('Connect a radio'), findsOneWidget);
    expect(connector.opened.length, opens, reason: 'no automatic connect');
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
