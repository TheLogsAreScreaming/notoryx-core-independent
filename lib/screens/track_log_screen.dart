import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/connection.dart';
import '../app/track_log.dart';
import '../data/data.dart';
import 'map_tab.dart' show mapTilesProvider;

final tracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(storeProvider).watchTracks(),
);

final trackPointsProvider = StreamProvider.family<List<TrackPoint>, int>(
  (ref, id) => ref.watch(storeProvider).watchTrackPoints(id),
);

String _distanceText(double metres) => metres < 1000
    ? '${metres.round()} m'
    : '${(metres / 1000).toStringAsFixed(2)} km';

String _dateText(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms).toString().substring(0, 16);

/// Record a walk from the phone's GPS, and save it as a GPX file.
class TrackLogScreen extends ConsumerWidget {
  const TrackLogScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final recorder = ref.read(trackRecorderProvider.notifier);
    if (ref.read(trackRecorderProvider) != null) {
      await recorder.stop();
      return;
    }
    try {
      await recorder.start(
        'Track ${_dateText(DateTime.now().millisecondsSinceEpoch)}',
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(trackRecorderProvider);
    final tracks = ref.watch(tracksProvider).value ?? const <Track>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Track log')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _toggle(context, ref),
                  icon: Icon(
                    active == null ? Icons.fiber_manual_record : Icons.stop,
                  ),
                  label: Text(
                    active == null ? 'Start recording' : 'Stop recording',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Uses your phone’s GPS and sends nothing over the mesh. '
                  'Recording stops if the app is closed.',
                ),
              ],
            ),
          ),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No tracks yet.'),
            ),
          for (final t in tracks)
            ListTile(
              leading: Icon(
                t.id == active ? Icons.radio_button_on : Icons.route,
              ),
              title: Text(t.name),
              subtitle: Text(
                t.id == active ? 'Recording' : _dateText(t.startedAt),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TrackDetailScreen(track: t),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One track on a map, with its length, export and delete.
class TrackDetailScreen extends ConsumerWidget {
  const TrackDetailScreen({required this.track, super.key});

  final Track track;

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await exportTrack(ref, track);
      messenger.showSnackBar(
        SnackBar(content: Text(saved ? 'GPX saved.' : 'Not saved.')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final store = ref.read(storeProvider);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this track?'),
        content: const Text('This can’t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await store.deleteTrack(track.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points =
        ref.watch(trackPointsProvider(track.id)).value ?? const <TrackPoint>[];
    final line = [for (final p in points) LatLng(p.latitude, p.longitude)];
    final recording = ref.watch(trackRecorderProvider) == track.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(track.name),
        actions: [
          IconButton(
            tooltip: 'Save as GPX',
            onPressed: points.isEmpty ? null : () => _export(context, ref),
            icon: const Icon(Icons.save_alt),
          ),
          IconButton(
            tooltip: 'Delete track',
            onPressed: recording ? null : () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: Text(_distanceText(trackLengthMetres(points))),
            subtitle: Text('${points.length} points'),
          ),
          Expanded(
            child: line.isEmpty
                ? const Center(child: Text('No points yet.'))
                : FlutterMap(
                    key: ValueKey(line.length > 1),
                    options: MapOptions(
                      initialCenter: line.first,
                      initialZoom: 14,
                      initialCameraFit: line.length > 1
                          ? CameraFit.coordinates(
                              coordinates: line,
                              padding: const EdgeInsets.all(32),
                              maxZoom: 16,
                            )
                          : null,
                    ),
                    children: [
                      ?ref.watch(mapTilesProvider),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: line,
                            strokeWidth: 4,
                            color: Theme.of(context).colorScheme.primary,
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
        ],
      ),
    );
  }
}
