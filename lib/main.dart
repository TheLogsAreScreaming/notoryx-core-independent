import 'package:flutter/material.dart';

void main() {
  runApp(const NotoryxApp());
}

/// Root widget for NOTORYX Core. Screens arrive phase by phase as the
/// radio core, data layer and UI are written for this repository.
class NotoryxApp extends StatelessWidget {
  const NotoryxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOTORYX Core',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8721C),
          brightness: Brightness.dark,
        ),
      ),
      home: const _PlaceholderScreen(),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('NOTORYX Core — in development')),
    );
  }
}
