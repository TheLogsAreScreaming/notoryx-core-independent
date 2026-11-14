import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/appearance.dart';
import 'app/bots.dart';
import 'app/channel_cleanup.dart';
import 'app/home_widget.dart';
import 'app/keep_alive.dart';
import 'app/language.dart';
import 'app/packet_log.dart';
import 'app/radio_stats.dart';
import 'app/safety.dart';
import 'app/sos_relay.dart';
import 'app/scheduled_messages.dart';
import 'app/telemetry.dart';
import 'app/connection.dart';
import 'app/mqtt_bridge.dart';
import 'app/network_scan.dart';
import 'app/zone_alerts.dart';
import 'app/node_journal.dart';
import 'app/path_graph.dart';
import 'app/notifications.dart';
import 'l10n/l10n.dart';
import 'screens/app_lock_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/home_screen.dart';
import 'screens/safety_screen.dart';

void main() {
  runApp(const ProviderScope(child: NotoryxApp()));
}

/// Lets a notification tap open a chat from outside the widget tree.
final _navigator = GlobalKey<NavigatorState>();

/// Root widget for NOTORYX Core.
class NotoryxApp extends ConsumerWidget {
  const NotoryxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider.select((a) => a.theme));
    return MaterialApp(
      title: 'NOTORYX Core',
      navigatorKey: _navigator,
      theme: themeFor(theme, Brightness.light),
      darkTheme: themeFor(theme, Brightness.dark),
      themeMode: theme.mode,
      locale: ref.watch(languageProvider).value,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => AppLockGate(child: child!),
      home: const _RadioGate(),
    );
  }
}

/// Always shows the full app: the connected radio's chats, or the last
/// radio's saved ones when none is connected. Connecting is a screen opened
/// from there. Also sets up message notifications.
class _RadioGate extends ConsumerStatefulWidget {
  const _RadioGate();

  @override
  ConsumerState<_RadioGate> createState() => _RadioGateState();
}

class _RadioGateState extends ConsumerState<_RadioGate> {
  /// A chat a notification asked for before its radio's chats were showing.
  ChatLink? _pendingChat;

  /// What the home screen last showed, kept through a connection attempt.
  ({String key, String name})? _shown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      listenForWidgetTaps(_openSafety);
      final launched = await ref.read(messageNotifierProvider).init(_openChat);
      if (launched != null) _openChat(launched);
    });
  }

  void _openSafety() {
    if (!mounted) return;
    _navigator.currentState?.popUntil((route) => route.isFirst);
    _navigator.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => const SafetyScreen()),
    );
  }

  void _openChat(ChatLink chat) {
    // Alerts about no one chat (your own radio) just bring the app up.
    if (!mounted || chat.thread.isEmpty) return;
    if (ref.read(radioKeyProvider) case null || '') {
      _pendingChat = chat; // opened once the chats are showing
      return;
    }
    _pendingChat = null;
    _navigator.currentState?.popUntil((route) => route.isFirst);
    _navigator.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          thread: chat.thread,
          title: chat.title,
          isChannel: chat.isChannel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(messageAlertsProvider);
    ref.watch(keepAliveWatcherProvider);
    // Listened, not watched: a packet mustn't rebuild the whole app.
    ref.listen(packetLogProvider, (_, _) {});
    ref.listen(selfTelemetrySamplerProvider, (_, _) {});
    ref.listen(radioStatsSamplerProvider, (_, _) {});
    ref.listen(checkInWatchdogProvider, (_, _) {});
    ref.listen(sosWatchdogProvider, (_, _) {});
    ref.listen(tripQuietWatchdogProvider, (_, _) {});
    ref.listen(sosRelayRunnerProvider, (_, _) {});
    ref.listen(scanRestoreProvider, (_, _) {});
    ref.listen(pathRecorderProvider, (_, _) {});
    ref.listen(journalRecorderProvider, (_, _) {});
    ref.listen(zoneWatcherProvider, (_, _) {});
    ref.listen(mqttBridgeProvider, (_, _) {});
    ref.listen(homeWidgetSyncProvider, (_, _) {});
    ref.listen(scheduledSenderProvider, (_, _) {});
    ref.listen(botRunnerProvider, (_, _) {});
    ref.listen(channelCleanerProvider, (_, _) {});
    // Connecting closes the connect screen, and disconnecting closes any
    // open conversation. While reconnecting the chats stay open.
    ref.listen(connectionProvider, (previous, next) {
      bool showsChats(RadioConnectionState? s) =>
          s is Connected || s is Reconnecting || s is ViewingSaved;
      bool live(RadioConnectionState? s) => s is Connected || s is Reconnecting;
      final hasChats = showsChats(next);
      if (live(previous) != live(next)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      if (hasChats && _pendingChat != null) {
        final chat = _pendingChat!;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openChat(chat));
      }
    });
    final state = ref.watch(connectionProvider);
    final saved = ref.watch(savedRadiosProvider);
    // A radio can appear while none is connected, by restoring a backup.
    final radio = saved.value?.firstOrNull;
    final noRadioYet =
        state is ViewingSaved &&
        !(saved.value ?? const []).any((r) => r.publicKey == state.radioKey);
    if ((state is Disconnected || (noRadioYet && radio != null)) &&
        !saved.isLoading) {
      final error = state is Disconnected ? state.error : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ref.read(connectionProvider) != state) return;
        ref
            .read(connectionProvider.notifier)
            .viewSaved(
              radioKey: radio?.publicKey ?? '',
              radioName: radio?.name ?? 'NOTORYX Core',
              error: error,
            );
      });
    }
    _shown = switch (state) {
      Connected(:final radio) => (key: radio.key, name: radio.self.name),
      Reconnecting(:final radioKey, :final radioName) ||
      ViewingSaved(
        :final radioKey,
        :final radioName,
      ) => (key: radioKey, name: radioName),
      _ => _shown,
    };
    return switch (_shown) {
      (:final key, :final name) => HomeScreen(radioKey: key, radioName: name),
      null => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
