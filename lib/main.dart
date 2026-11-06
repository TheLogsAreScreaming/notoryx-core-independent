import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/connection.dart';
import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: NotoryxApp()));
}

/// Root widget for NOTORYX Core.
class NotoryxApp extends StatelessWidget {
  const NotoryxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOTORYX Core',
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
/// connect screen otherwise.
class _RadioGate extends ConsumerWidget {
  const _RadioGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Disconnecting closes any open conversation so the connect screen is
    // what's showing. While reconnecting the chats stay open.
    ref.listen(connectionProvider, (previous, next) {
      final hadChats = previous is Connected || previous is Reconnecting;
      final hasChats = next is Connected || next is Reconnecting;
      if (hadChats && !hasChats) {
        Navigator.of(context).popUntil((route) => route.isFirst);
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
