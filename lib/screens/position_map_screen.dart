import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'map_tab.dart';
import '../l10n/l10n.dart';

/// One shared position on a map, with a way to copy it.
class PositionMapScreen extends ConsumerWidget {
  const PositionMapScreen({
    required this.position,
    required this.label,
    super.key,
  });

  final LatLng position;

  /// Whose position it is, e.g. "Ridge".
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(mapTilesProvider);
    final scheme = Theme.of(context).colorScheme;
    final coordinates =
        '${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        actions: [
          IconButton(
            tooltip: context.l10n.copyCoordinates,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: coordinates));
              messenger.showSnackBar(
                SnackBar(content: Text('Copied $coordinates')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(coordinates),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: position, initialZoom: 14),
              children: [
                ?tiles,
                MarkerLayer(
                  markers: [
                    Marker(
                      point: position,
                      width: 40,
                      height: 40,
                      child: Semantics(
                        label: '$label at $coordinates',
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: scheme.error,
                        ),
                      ),
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
