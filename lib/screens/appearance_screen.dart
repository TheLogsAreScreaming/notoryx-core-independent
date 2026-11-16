import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_background.dart';
import '../app/appearance.dart';
import '../l10n/l10n.dart';
import '../app/language.dart';
import '../app/link_preview.dart';
import 'background_layer.dart';

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
          SwitchListTile(
            secondary: const Icon(Icons.link),
            title: Text(context.l10n.linkPreviewsAuto),
            subtitle: Text(context.l10n.linkPreviewsAutoSubtitle),
            value: ref.watch(linkPreviewsAutoProvider).value ?? false,
            onChanged: ref.read(linkPreviewsAutoProvider.notifier).set,
          ),
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
                  semanticFormatterCallback: (_) => context.l10n.percentSpoken(
                    (look.chatScale * 100).round(),
                  ),
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
          const BackgroundSection(),
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
                    title: Text(t.label(context.l10n)),
                    subtitle: Text(t.description(context.l10n)),
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

/// Picks what sits behind the main screens.
class BackgroundSection extends ConsumerWidget {
  const BackgroundSection({super.key});

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notPicture = context.l10n.photoNotImage;
    final jpeg = await ref.read(backgroundPhotoPickerProvider)();
    if (jpeg == null) return;
    if (jpeg.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(notPicture)));
      return;
    }
    await ref.read(appBackgroundProvider.notifier).usePhoto(jpeg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bg = ref.watch(appBackgroundProvider);
    final notifier = ref.read(appBackgroundProvider.notifier);
    final theme = Theme.of(context);
    final names = l10n.backgroundColourNames.split(',');
    String kindLabel(BackgroundKind k) => switch (k) {
      BackgroundKind.theme => l10n.backgroundTheme,
      BackgroundKind.solid => l10n.backgroundSolid,
      BackgroundKind.gradient => l10n.backgroundGradient,
      BackgroundKind.mesh => l10n.backgroundMesh,
      BackgroundKind.photo => l10n.backgroundPhoto,
    };
    Widget swatches(String label, Color selected, ValueChanged<Color> pick) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                children: [
                  for (var i = 0; i < backgroundColours.length; i++)
                    Semantics(
                      button: true,
                      selected: backgroundColours[i] == selected,
                      label: i < names.length ? names[i] : null,
                      child: InkResponse(
                        onTap: () => pick(backgroundColours[i]),
                        radius: 24,
                        child: SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: backgroundColours[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: backgroundColours[i] == selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                  width: backgroundColours[i] == selected
                                      ? 3
                                      : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.wallpaper),
          title: Text(l10n.background, style: theme.textTheme.titleMedium),
          subtitle: Text(l10n.backgroundIntro),
        ),
        RadioGroup<BackgroundKind>(
          groupValue: bg.kind,
          onChanged: (k) async {
            if (k == null) return;
            if (k == BackgroundKind.photo && bg.photoPath == null) {
              await _pickPhoto(context, ref);
              return;
            }
            await notifier.set(bg.copyWith(kind: k));
          },
          child: Column(
            children: [
              for (final k in BackgroundKind.values)
                RadioListTile<BackgroundKind>(
                  value: k,
                  title: Text(kindLabel(k)),
                ),
            ],
          ),
        ),
        if (bg.kind
            case BackgroundKind.solid ||
                BackgroundKind.gradient ||
                BackgroundKind.mesh)
          swatches(
            bg.kind == BackgroundKind.solid
                ? l10n.backgroundColour
                : l10n.backgroundFirstColour,
            bg.first,
            (c) => notifier.set(bg.copyWith(first: c)),
          ),
        if (bg.kind case BackgroundKind.gradient || BackgroundKind.mesh)
          swatches(
            l10n.backgroundSecondColour,
            bg.second,
            (c) => notifier.set(bg.copyWith(second: c)),
          ),
        if (bg.kind == BackgroundKind.photo)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.backgroundChoosePhoto),
              onPressed: () => _pickPhoto(context, ref),
            ),
          ),
        if (bg.isCustom) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(l10n.backgroundDim, style: theme.textTheme.titleSmall),
          ),
          Slider(
            value: bg.dim,
            max: maxDim,
            divisions: 17,
            label: '${(bg.dim * 100).round()}%',
            semanticFormatterCallback: (v) => '${(v * 100).round()}%',
            onChanged: (v) => notifier.set(bg.copyWith(dim: v)),
          ),
          if (bg.kind == BackgroundKind.photo) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                l10n.backgroundBlur,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Slider(
              value: bg.blur,
              max: maxBlur,
              divisions: 20,
              label: bg.blur.round().toString(),
              semanticFormatterCallback: (v) => v.round().toString(),
              onChanged: (v) => notifier.set(bg.copyWith(blur: v)),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.backgroundReadableNote,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 140,
                child: BackgroundLayer(
                  child: Center(
                    child: GlassCard(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(l10n.backgroundPreviewTitle),
                        subtitle: Text(l10n.summitAtNoonBringWater),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
