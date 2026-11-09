import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presets/community_presets.dart';
import 'area_screen.dart';
import '../l10n/l10n.dart';

/// MeshCore's community presets, with search and your country first.
class CommunityPresetsScreen extends ConsumerStatefulWidget {
  const CommunityPresetsScreen({super.key});

  @override
  ConsumerState<CommunityPresetsScreen> createState() =>
      _CommunityPresetsScreenState();
}

class _CommunityPresetsScreenState
    extends ConsumerState<CommunityPresetsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(communityPresetsProvider).value ?? const [];
    final shown = sortCommunityPresets(
      presets,
      country: PlatformDispatcher.instance.locale.countryCode,
      query: _query,
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.communityPresets)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: context.l10n.search,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          for (final preset in shown)
            ListTile(
              title: Text(preset.name),
              subtitle: Text(preset.summary),
              onTap: () => reviewArea(context, ref, preset),
            ),
          if (shown.isEmpty) ListTile(title: Text(context.l10n.noMatches)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'From MeshCore’s community list. Make sure a preset is legal '
              'where you are. Your country is taken from this phone’s '
              'language settings.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
