import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'app_lock.dart';
import 'blocking.dart';
import 'spam_filter.dart';
import 'connection.dart';

/// A chat to open, carried by a notification.
typedef ChatLink = ({String thread, String title, bool isChannel});

/// Shows message notifications. The app uses [LocalMessageNotifier]; tests
/// swap in a fake.
abstract interface class MessageNotifier {
  /// Prepares notifications and asks for permission. [onOpen] runs when the
  /// person taps one. Returns the chat if a notification launched the app.
  Future<ChatLink?> init(void Function(ChatLink chat) onOpen);

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required ChatLink chat,
  });
}

final class LocalMessageNotifier implements MessageNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'messages';

  @override
  Future<ChatLink?> init(void Function(ChatLink chat) onOpen) async {
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: darwin,
        macOS: darwin,
        windows: WindowsInitializationSettings(
          appName: 'NOTORYX Independent',
          appUserModelId: 'BastionMesh.NotoryxIndependent',
          guid: '0277b9dd-2b81-4f49-939b-30acccb4dab8',
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final chat = _decode(response.payload);
        if (chat != null) onOpen(chat);
      },
    );
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? _decode(launch!.notificationResponse?.payload)
        : null;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required ChatLink chat,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Messages',
        channelDescription: 'New channel and direct messages',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    ),
    payload: jsonEncode({
      'thread': chat.thread,
      'title': chat.title,
      'isChannel': chat.isChannel,
    }),
  );

  static ChatLink? _decode(String? payload) {
    if (payload == null) return null;
    try {
      final json = jsonDecode(payload) as Map<String, Object?>;
      return (
        thread: json['thread']! as String,
        title: json['title']! as String,
        isChannel: json['isChannel'] == true,
      );
    } on Object {
      return null;
    }
  }
}

final messageNotifierProvider = Provider<MessageNotifier>(
  (ref) => LocalMessageNotifier(),
);

/// Whether the app is in front, for deciding when to notify.
typedef ForegroundCheck = bool Function();

final foregroundCheckProvider = Provider<ForegroundCheck>(
  (ref) =>
      () => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
);

/// Notifies about new messages while a radio is connected. Skips muted
/// chats, and the chat already open on screen while the app is in front.
final messageAlertsProvider = Provider<void>((ref) {
  final state = ref.watch(connectionProvider);
  if (state is! Connected) return;
  final key = state.radio.key;
  final store = ref.read(storeProvider);
  final notifier = ref.read(messageNotifierProvider);
  final inFront = ref.read(foregroundCheckProvider);
  final sub = state.sync.incoming.listen((message) async {
    final open = ref.read(openThreadProvider);
    if (inFront() && open == message.thread) return;
    final blocked = await readBlockList(store);
    if (blocked.blocks(message)) return;
    if (await store.setting(spamFilterSetting) == '1' &&
        spamRepeats(
          await store.threadSnapshot(key, message.thread),
          myName: state.radio.self.name,
        ).contains(message.id)) {
      return;
    }
    // A mention gets through even in a muted chat.
    final mentioned = mentions(message.body, state.radio.self.name);
    if (!mentioned && await store.isMuted(key, message.thread)) return;
    final chat = await chatLinkFor(store, key, message.thread);
    final body =
        message.kind == MessageKind.channel && message.senderName != null
        ? '${message.senderName}: ${message.body}'
        : message.body;
    // A locked app shouldn't show its messages on the lock screen.
    final hide = parseAppLock(await store.setting(appLockSetting)).enabled;
    await notifier.show(
      id: message.id,
      title: hide
          ? 'NOTORYX Core'
          : mentioned
          ? '${chat.title}: mentioned you'
          : chat.title,
      body: hide ? 'New message' : body,
      chat: chat,
    );
  });
  ref.onDispose(sub.cancel);
});

/// The name to show for [thread]: the channel or contact name, or a key
/// prefix for someone not yet a contact.
Future<ChatLink> chatLinkFor(
  MeshStore store,
  String radioKey,
  String thread,
) async {
  final id = thread.substring(2);
  if (thread.startsWith('c:')) {
    final channels = await store.watchChannels(radioKey).first;
    final slot = int.parse(id);
    final name = channels.where((c) => c.slot == slot).firstOrNull?.name;
    return (thread: thread, title: name ?? 'Channel $slot', isChannel: true);
  }
  final contacts = await store.watchContacts(radioKey).first;
  final name = contacts.where((c) => c.publicKey == id).firstOrNull?.name;
  return (
    thread: thread,
    title: name ?? 'Unknown ${id.substring(0, 6)}',
    isChannel: false,
  );
}
