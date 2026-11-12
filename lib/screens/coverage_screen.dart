import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/coverage.dart';
import '../l10n/l10n.dart';
import '../presets/area_presets_provider.dart';
import '../data/data.dart';
import 'map_tab.dart' show mapTilesProvider;
import 'wardrive_screen.dart' show wardriveColor;

/// Wardrive pings as coverage hexagons, and a line-of-sight check.
class CoverageScreen extends ConsumerStatefulWidget {
  const CoverageScreen({super.key});

  @override
  ConsumerState<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends ConsumerState<CoverageScreen> {
  String? _repeater;
  final _mine = TextEditingController(text: '2');
  final _other = TextEditingController(text: '10');
  final _km = TextEditingController(text: '5');

  @override
  void dispose() {
    _mine.dispose();
    _other.dispose();
    _km.dispose();
    super.dispose();
  }

  Widget _number(TextEditingController c, String label) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pings = ref.watch(coveragePingsProvider).value ?? const [];
    final radioKey = ref.watch(radioKeyProvider) ?? '';
    final names = <String, String>{
      for (final c
          in ref.watch(contactsProvider(radioKey)).value ?? const <Contact>[])
        c.publicKey: c.name,
    };
    final repeaters = {
      for (final p in pings)
        for (final h in p.hits) h.repeater,
    }.toList()..sort();
    final origin = pings.isEmpty ? null : pings.first.at;
    final cells = origin == null
        ? const <CoverageCell>[]
        : coverageCells(pings, origin, repeater: _repeater);
    final mine = double.tryParse(_mine.text) ?? 0;
    final other = double.tryParse(_other.text) ?? 0;
    final km = double.tryParse(_km.text) ?? 0;
    final horizon = radioHorizonKm(mine, other);
    final mhz = ref.watch(radioSettingsProvider)?.frequencyMhz ?? 910;
    final losText = km <= horizon
        ? context.l10n.withinHorizon(
            horizon.toStringAsFixed(1),
            (fresnelMetres(km, mhz) * 0.6).toStringAsFixed(0),
          )
        : context.l10n.beyondHorizon(horizon.toStringAsFixed(1));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.coverage)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.coverageIntro),
          ),
          if (origin == null)
            ListTile(title: Text(context.l10n.noCoverageYet))
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _repeater,
                items: [
                  DropdownMenuItem(child: Text(context.l10n.allRepeaters)),
                  for (final r in repeaters)
                    DropdownMenuItem(
                      value: r,
                      child: Text(names[r] ?? r.substring(0, 8).toUpperCase()),
                    ),
                ],
                onChanged: (r) => setState(() => _repeater = r),
              ),
            ),
            SizedBox(
              height: 360,
              child: FlutterMap(
                key: ValueKey(_repeater),
                options: MapOptions(
                  initialCenter: origin,
                  initialZoom: 12,
                  initialCameraFit: pings.length > 1
                      ? CameraFit.coordinates(
                          coordinates: [for (final p in pings) p.at],
                          padding: const EdgeInsets.all(32),
                          maxZoom: 15,
                        )
                      : null,
                ),
                children: [
                  ?ref.watch(mapTilesProvider),
                  PolygonLayer(
                    polygons: [
                      for (final c in cells)
                        Polygon(
                          points: hexCorners(c.hex, origin),
                          color: wardriveColor(c.best).withValues(alpha: 0.45),
                          borderColor: wardriveColor(c.best),
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
          const Divider(),
          ListTile(
            title: Text(
              context.l10n.lineOfSight,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(context.l10n.lineOfSightIntro),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 12,
              children: [
                _number(_mine, context.l10n.yourAntennaHeight),
                _number(_other, context.l10n.otherAntennaHeight),
                _number(_km, context.l10n.distanceKm),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Text(losText)),
        ],
      ),
    );
  }
}
