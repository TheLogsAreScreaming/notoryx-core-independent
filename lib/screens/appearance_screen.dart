import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/appearance.dart';

/// Pick a theme and the size of chat text.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final index = chatScales.indexOf(look.chatScale);
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat text size',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: (index < 0 ? 1 : index).toDouble(),
                  max: chatScales.length - 1.0,
                  divisions: chatScales.length - 1,
                  label: '${(look.chatScale * 100).round()}%',
                  semanticFormatterCallback: (_) =>
                      '${(look.chatScale * 100).round()} percent',
                  onChanged: (v) =>
                      notifier.setChatScale(chatScales[v.round()]),
                ),
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      MediaQuery.textScalerOf(context).scale(1) *
                          look.chatScale,
                    ),
                  ),
                  child: const Text('Summit at noon. Bring water.'),
                ),
              ],
            ),
          ),
          const Divider(),
          RadioGroup<AppThemeChoice>(
            groupValue: look.theme,
            onChanged: (t) {
              if (t != null) notifier.setTheme(t);
            },
            child: Column(
              children: [
                for (final t in AppThemeChoice.values)
                  RadioListTile<AppThemeChoice>(
                    value: t,
                    title: Text(t.label),
                    subtitle: Text(t.description),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
