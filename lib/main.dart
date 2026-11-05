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

/// Shows the connect screen until a radio is connected and synced.
class _RadioGate extends ConsumerWidget {
  const _RadioGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Losing the radio closes any open conversation so the connect screen
    // is what's showing.
    ref.listen(connectionProvider, (previous, next) {
      if (previous is Connected && next is! Connected) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    return switch (ref.watch(connectionProvider)) {
      Connected(:final radio) => HomeScreen(radio: radio),
      _ => const ConnectScreen(),
    };
  }
}
