import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/map_packs.dart';
import '../l10n/l10n.dart';

/// Import raster MBTiles map packs and pick which one the map uses
/// offline.
class MapPacksScreen extends ConsumerStatefulWidget {
  const MapPacksScreen({super.key});

  @override
  ConsumerState<MapPacksScreen> createState() => _MapPacksScreenState();
}

class _MapPacksScreenState extends ConsumerState<MapPacksScreen> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final packs = ref.watch(mapPacksProvider);
    final active = ref.watch(activeMapPackProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offlineMapPacks)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_open_outlined),
        label: Text(l10n.importMapPack),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.mapPacksIntro),
          ),
          RadioGroup<String?>(
            groupValue: active,
            onChanged: (v) => chooseMapPack(ref, v),
            child: Column(
              children: [
                RadioListTile<String?>(
                  value: null,
                  title: Text(l10n.mapPackNone),
                  subtitle: Text(l10n.mapPackNoneSubtitle),
                ),
                ...switch (packs) {
                  AsyncData(:final value) => [
                    for (final pack in value)
                      RadioListTile<String?>(
                        value: pack.fileName,
                        title: Text(pack.name),
                        subtitle: Text(
                          [
                            l10n.mapPackZooms(pack.minZoom, pack.maxZoom),
                            l10n.mapPackSize(
                              (pack.bytes / 1e6).toStringAsFixed(1),
                              pack.tileCount,
                            ),
                            if (pack.attribution case final a?
                                when a.trim().isNotEmpty)
                              a.replaceAll(RegExp('<[^>]*>'), ''),
                          ].join('\n'),
                        ),
                        secondary: IconButton(
                          tooltip: l10n.deleteMapPack(pack.name),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(pack),
                        ),
                      ),
                  ],
                  AsyncError() => [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.mapPacksUnreadable),
                    ),
                  ],
                  _ => [const LinearProgressIndicator()],
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final pick = ref.read(mapPackPickerProvider);
    final path = await pick();
    if (path == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final dir = await ref.read(mapPackDirProvider.future);
      final info = await importMapPack(dir, path);
      ref.invalidate(mapPacksProvider);
      await chooseMapPack(ref, info.fileName);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mapPackImported(info.name))),
      );
    } on MapPackException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.reason) {
            MapPackProblem.notMbtiles => l10n.mapPackNotMbtiles,
            MapPackProblem.vectorTiles => l10n.mapPackVector,
            MapPackProblem.empty => l10n.mapPackEmpty,
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _delete(MapPackInfo pack) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.deleteMapPack(pack.name)),
        content: Text(l10n.thisCanTBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (sure == true) await deleteMapPack(ref, pack.fileName);
  }
}
