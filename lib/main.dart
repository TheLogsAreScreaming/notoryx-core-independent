import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/keep_alive.dart';
import 'app/packet_log.dart';
import 'app/radio_stats.dart';
import 'app/safety.dart';
import 'app/telemetry.dart';
import 'app/connection.dart';
import 'app/notifications.dart';
import 'screens/connect_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: NotoryxApp()));
}

/// Lets a notification tap open a chat from outside the widget tree.
final _navigator = GlobalKey<NavigatorState>();

/// Root widget for NOTORYX Core.
class NotoryxApp extends StatelessWidget {
  const NotoryxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOTORYX Core',
      navigatorKey: _navigator,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const _RadioGate(),
    );
  }

  static ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFE8721C),
      brightness: brightness,
    ),
  );
}

/// Shows the chats while a radio is connected or being reconnected, and the
/// connect screen otherwise. Also sets up message notifications.
class _RadioGate extends ConsumerStatefulWidget {
  const _RadioGate();

  @override
  ConsumerState<_RadioGate> createState() => _RadioGateState();
}

class _RadioGateState extends ConsumerState<_RadioGate> {
  /// A chat a notification asked for before its radio's chats were showing.
  ChatLink? _pendingChat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launched = await ref.read(messageNotifierProvider).init(_openChat);
      if (launched != null) _openChat(launched);
    });
  }

  void _openChat(ChatLink chat) {
    if (!mounted) return;
    if (ref.read(radioKeyProvider) == null) {
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
    // Disconnecting closes any open conversation so the connect screen is
    // what's showing. While reconnecting the chats stay open.
    ref.listen(connectionProvider, (previous, next) {
      final hadChats = previous is Connected || previous is Reconnecting;
      final hasChats = next is Connected || next is Reconnecting;
      if (hadChats && !hasChats) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      if (hasChats && _pendingChat != null) {
        final chat = _pendingChat!;
        WidgetsBinding.instance.addPostFrameCallback((_) => _openChat(chat));
      }
    });
    return switch (ref.watch(connectionProvider)) {
      Connected(:final radio) => HomeScreen(
        radioKey: radio.key,
        radioName: radio.self.name,
      ),
      Reconnecting(:final radioKey, :final radioName) => HomeScreen(
        radioKey: radioKey,
        radioName: radioName,
      ),
      _ => const ConnectScreen(),
    };
  }
}
