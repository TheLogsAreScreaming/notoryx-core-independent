import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/connection.dart';
import '../app/wardrive.dart';
import '../l10n/l10n.dart';
import 'map_tab.dart' show mapTilesProvider;
import 'coverage_screen.dart';

/// The colour for a ping's best two-way link.
Color wardriveColor(double? best) => switch (best) {
  null => const Color(0xFF9E9E9E),
  >= 5 => const Color(0xFF009E73),
  >= -5 => const Color(0xFFE69F00),
  _ => const Color(0xFFD55E00),
};

/// Starts and stops a wardrive, and shows drives on a map.
class WardriveScreen extends ConsumerStatefulWidget {
  const WardriveScreen({super.key});

  @override
  ConsumerState<WardriveScreen> createState() => _WardriveScreenState();
}

class _WardriveScreenState extends ConsumerState<WardriveScreen> {
  Duration _every = const Duration(seconds: 30);
  int? _shown;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(wardriveProvider);
    final recorder = ref.read(wardriveProvider.notifier);
    final connected = ref.watch(connectionProvider) is Connected;
    final drives = ref.watch(wardrivesProvider).value ?? const [];
    final shown = active ?? _shown ?? drives.firstOrNull?.id;
    final points = shown == null
        ? const <WardrivePoint>[]
        : ref.watch(wardrivePointsProvider(shown)).value ?? const [];
    final coords = [for (final p in points) LatLng(p.latitude, p.longitude)];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.wardrive),
        actions: [
          IconButton(
            tooltip: context.l10n.coverage,
            icon: const Icon(Icons.hexagon_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CoverageScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.wardriveIntro),
          ),
          ListTile(
            title: Text(context.l10n.pingEvery),
            trailing: DropdownButton<Duration>(
              value: _every,
              items: [
                for (final d in wardriveIntervals)
                  DropdownMenuItem(
                    value: d,
                    child: Text(
                      d.inMinutes == 0
                          ? '${d.inSeconds} s'
                          : '${d.inMinutes} min',
                    ),
                  ),
              ],
              onChanged: active != null
                  ? null
                  : (d) => setState(() => _every = d ?? _every),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: active != null
                ? FilledButton.icon(
                    icon: const Icon(Icons.stop),
                    label: Text(context.l10n.stopWardrive),
                    onPressed: recorder.stop,
                  )
                : FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(context.l10n.startWardrive),
                    onPressed: connected ? () => recorder.start(_every) : null,
                  ),
          ),
          if (!connected && active == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.connectToStartWardrive),
            ),
          if (recorder.lastResult case final result? when active != null)
            ListTile(title: Text(result)),
          if (coords.isNotEmpty) ...[
            SizedBox(
              height: 320,
              child: FlutterMap(
                key: ValueKey('$shown:${coords.length > 1}'),
                options: MapOptions(
                  initialCenter: coords.last,
                  initialZoom: 13,
                  initialCameraFit: coords.length > 1
                      ? CameraFit.coordinates(
                          coordinates: coords,
                          padding: const EdgeInsets.all(32),
                          maxZoom: 16,
                        )
                      : null,
                ),
                children: [
                  ?ref.watch(mapTilesProvider),
                  CircleLayer(
                    circles: [
                      for (final p in points)
                        CircleMarker(
                          point: LatLng(p.latitude, p.longitude),
                          radius: 8,
                          color: wardriveColor(p.best),
                          borderColor: Colors.black,
                          borderStrokeWidth: 1,
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.wardriveLegend,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          ListTile(title: Text(context.l10n.savedDrives)),
          if (drives.isEmpty) ListTile(title: Text(context.l10n.noDrivesYet)),
          for (final d in drives)
            ListTile(
              selected: d.id == shown,
              title: Text(d.name),
              onTap: () => setState(() => _shown = d.id),
              trailing: d.id == active
                  ? const Icon(Icons.radio_button_on)
                  : IconButton(
                      tooltip: context.l10n.deleteDrive,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        if (_shown == d.id) setState(() => _shown = null);
                        deleteWardrive(ref.read(databaseProvider), d.id);
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
