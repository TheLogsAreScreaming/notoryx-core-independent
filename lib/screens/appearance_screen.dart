import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/appearance.dart';
import '../l10n/l10n.dart';
import '../app/language.dart';

/// Pick a theme and the size of chat text.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final index = chatScales.indexOf(look.chatScale);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appearance)),
      body: ListView(
        children: [
          const _LanguageTile(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.chatTextSize,
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
                  child: Text(context.l10n.summitAtNoonBringWater),
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

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(languageProvider).value?.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.translate),
          title: Text(context.l10n.language),
          trailing: DropdownButton<String?>(
            value: chosen,
            items: [
              DropdownMenuItem(child: Text(context.l10n.phoneSetting)),
              for (final MapEntry(:key, :value) in appLanguages.entries)
                DropdownMenuItem(value: key, child: Text(value)),
            ],
            onChanged: (code) =>
                ref.read(languageProvider.notifier).choose(code),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            context.l10n.machineTranslatedNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
