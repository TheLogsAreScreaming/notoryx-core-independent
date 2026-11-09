import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presets/area_preset.dart';
import '../presets/area_presets_provider.dart';
import 'community_presets_screen.dart';
import '../l10n/l10n.dart';

/// "Phoenix, Arizona uses…" with Not now and Review, shown when the radio
/// isn't on its area's settings.
class AreaBanner extends ConsumerWidget {
  const AreaBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(areaOfferProvider);
    if (offer == null) return const SizedBox.shrink();
    final area = offer.area;
    final scheme = Theme.of(context).colorScheme;
    final who = area.fromMap
        ? 'Most radios around ${area.name}'
              '${area.nodeCount == null ? '' : ' (${area.nodeCount} on the MeshCore map)'}'
              ' use'
        : 'The ${area.name} mesh uses';
    return Material(
      key: const ValueKey('area-banner'),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.yourRadioIsSetDifferentlySo(who, area.summary),
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () =>
                        ref.read(dismissedAreaProvider.notifier).dismiss(area),
                    child: Text(context.l10n.notNow),
                  ),
                  FilledButton.tonal(
                    onPressed: () => reviewArea(context, ref, area),
                    child: Text(context.l10n.review),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows what would change, then applies [area] to the radio if confirmed.
Future<void> reviewArea(
  BuildContext context,
  WidgetRef ref,
  AreaPreset area,
) async {
  final radio = ref.read(radioSettingsProvider);
  final changes = radio == null ? const <String>[] : area.changesFrom(radio);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.useSettings(area.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (radio == null)
              Text(context.l10n.connectYourRadioToChangeIts)
            else if (changes.isEmpty)
              Text(context.l10n.yourRadioAlreadyUsesTheseSettings)
            else
              for (final change in changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $change'),
                ),
            if (area.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(area.notes),
            ],
            if (area.pathHashBytes case final bytes?) ...[
              const SizedBox(height: 8),
              Text(context.l10n.thisAreaAlsoUsesBytePaths(bytes)),
            ],
            const SizedBox(height: 8),
            Text(
              '${area.fromMap ? 'Reported by node owners on the MeshCore map, not checked on air. ' : ''}'
              'Updated ${area.updated}. After switching you will only hear '
              'radios on the same settings. Transmit power is not changed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: changes.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          child: Text(context.l10n.applyToRadio),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await applyArea(ref, area);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.radioSetToSettings(area.name))),
    );
  } on Object catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.couldNotChangeTheRadio(e))),
    );
  }
}

/// Picks which area's settings to follow: automatic, or one from the list,
/// nearest to the radio first.
class AreaScreen extends ConsumerWidget {
  const AreaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(areaPresetsProvider).value ?? const [];
    final choice = ref.watch(areaChoiceProvider).value ?? autoArea;
    final active = ref.watch(activeAreaProvider);
    final at = ref.watch(radioPositionProvider);
    final sorted = [...areas];
    if (at != null) {
      sorted.sort(
        (a, b) => a
            .distanceKm(at.lat, at.lon)
            .compareTo(b.distanceKm(at.lat, at.lon)),
      );
    } else {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    }

    Future<void> choose(String? id) async {
      if (id == null) return;
      await ref.read(areaChoiceProvider.notifier).choose(id);
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.localMeshSettings)),
      body: RadioGroup<String>(
        groupValue: choice,
        onChanged: choose,
        child: ListView(
          children: [
            RadioListTile<String>(
              value: autoArea,
              title: Text(context.l10n.automatic),
              subtitle: Text(
                at == null
                    ? "Your radio has no position, so pick your area below."
                    : active == null
                    ? 'No listed area around your radio.'
                    : 'Around your radio: ${active.name}',
              ),
            ),
            if (active != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FilledButton.tonal(
                  onPressed: () => reviewArea(context, ref, active),
                  child: Text(context.l10n.reviewSettings(active.name)),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(context.l10n.communityPresets),
              subtitle: Text(context.l10n.meshcoreSListByCountry),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CommunityPresetsScreen(),
                ),
              ),
            ),
            const Divider(),
            for (final area in sorted)
              RadioListTile<String>(
                value: area.id,
                title: Text(area.name),
                subtitle: Text(
                  [
                    area.summary,
                    if (area.fromMap)
                      'MeshCore map${area.nodeCount == null ? '' : ', ${area.nodeCount} nodes'}',
                    if (at != null)
                      '${area.distanceKm(at.lat, at.lon).round()} km away',
                  ].join(' · '),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.areasComeFromThePublicMeshCore,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
