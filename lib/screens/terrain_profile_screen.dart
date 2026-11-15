import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../app/terrain_profile.dart';
import '../l10n/l10n.dart';
import '../presets/area_presets_provider.dart';
import 'node_details.dart' show distanceText;

/// The ground between your radio and a node, the direct line between the
/// antennas, and its first Fresnel zone.
class TerrainProfileScreen extends ConsumerStatefulWidget {
  const TerrainProfileScreen({
    super.key,
    required this.from,
    required this.to,
    required this.name,
  });

  final LatLng from;
  final LatLng to;
  final String name;

  @override
  ConsumerState<TerrainProfileScreen> createState() =>
      _TerrainProfileScreenState();
}

class _TerrainProfileScreenState extends ConsumerState<TerrainProfileScreen> {
  final _mine = TextEditingController(text: '2');
  final _other = TextEditingController(text: '10');
  List<double>? _ground;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _mine.dispose();
    _other.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final points = pathPoints(widget.from, widget.to, terrainSamples);
    final ground = await ref.read(elevationLookupProvider)(points);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _ground = ground;
      _failed = ground == null;
    });
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
    final l10n = context.l10n;
    final reported = ref.watch(radioSettingsProvider)?.frequencyMhz;
    final mhz = reported == null || reported <= 0
        ? defaultFresnelMhz
        : reported;
    final metres = const Distance().as(
      LengthUnit.Meter,
      widget.from,
      widget.to,
    );
    final ground = _ground;
    final profile = ground == null
        ? null
        : analyseProfile(
            elevations: ground,
            totalMetres: metres,
            startHeight: double.tryParse(_mine.text) ?? 0,
            endHeight: double.tryParse(_other.text) ?? 0,
            mhz: mhz,
          );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.terrainProfileTitle(widget.name))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.terrainProfileIntro),
          const SizedBox(height: 8),
          Text(
            l10n.terrainPathSummary(
              distanceText(widget.from, widget.to),
              mhz.toStringAsFixed(mhz == mhz.roundToDouble() ? 0 : 3),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 12,
            children: [
              _number(_mine, l10n.yourAntennaHeight),
              _number(_other, l10n.otherAntennaHeight),
            ],
          ),
          const SizedBox(height: 16),
          if (profile == null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.terrain),
                label: Text(l10n.terrainCheck),
              ),
            ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.terrainFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (profile != null) ...[
            FresnelVerdictRow(profile: profile),
            const SizedBox(height: 12),
            Semantics(
              label: l10n.terrainChartLabel,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 240,
                  child: CustomPaint(
                    painter: ProfilePainter(
                      profile: profile,
                      scheme: Theme.of(context).colorScheme,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const ProfileLegend(),
          ],
        ],
      ),
    );
  }
}

/// The one-line verdict on the Fresnel zone, with an icon.
class FresnelVerdictRow extends StatelessWidget {
  const FresnelVerdictRow({super.key, required this.profile});

  final PathProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (icon, colour, text) = switch (profile.verdict) {
      FresnelVerdict.clear => (
        Icons.check_circle_outline,
        scheme.primary,
        l10n.fresnelClear(profile.worstPercent),
      ),
      FresnelVerdict.partial => (
        Icons.warning_amber_rounded,
        scheme.tertiary,
        l10n.fresnelPartial(math.max(profile.worstPercent, 0)),
      ),
      FresnelVerdict.blocked => (
        Icons.block,
        scheme.error,
        l10n.fresnelBlocked,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Icon(icon, color: colour),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              Text(
                profile.lineOfSightClear
                    ? l10n.lineOfSightClearNote
                    : l10n.lineOfSightBlockedNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What each colour on the chart means.
class ProfileLegend extends StatelessWidget {
  const ProfileLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        ExcludeSemantics(child: SizedBox(width: 24, height: 12, child: swatch)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(ColoredBox(color: _groundColour(scheme)), l10n.legendGround),
        item(
          Center(child: Container(height: 2, color: scheme.primary)),
          l10n.legendDirectLine,
        ),
        item(
          ColoredBox(color: scheme.primary.withValues(alpha: 0.18)),
          l10n.legendFresnelZone,
        ),
        item(
          CustomPaint(painter: _DashPainter(scheme.primary)),
          l10n.legendFresnel60,
        ),
      ],
    );
  }
}

Color _groundColour(ColorScheme scheme) =>
    Color.lerp(scheme.secondary, scheme.surface, 0.35)!;

class _DashPainter extends CustomPainter {
  _DashPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 2;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 4, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.colour != colour;
}

/// Draws the ground, the direct line, the Fresnel zone around it and the
/// line 60% of the way into the zone.
class ProfilePainter extends CustomPainter {
  ProfilePainter({required this.profile, required this.scheme});

  final PathProfile profile;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final samples = profile.samples;
    if (samples.length < 2) return;
    var low = double.infinity, high = -double.infinity;
    for (final s in samples) {
      low = math.min(low, math.min(s.ground, s.beam - s.fresnel));
      high = math.max(high, math.max(s.ground, s.beam + s.fresnel));
    }
    final pad = math.max((high - low) * 0.08, 5.0);
    low -= pad;
    high += pad;
    final total = samples.last.distance <= 0 ? 1.0 : samples.last.distance;
    Offset at(double distance, double height) => Offset(
      distance / total * size.width,
      size.height - (height - low) / (high - low) * size.height,
    );

    final zone = Path();
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      final p = at(s.distance, s.beam + s.fresnel);
      i == 0 ? zone.moveTo(p.dx, p.dy) : zone.lineTo(p.dx, p.dy);
    }
    for (final s in samples.reversed) {
      final p = at(s.distance, s.beam - s.fresnel);
      zone.lineTo(p.dx, p.dy);
    }
    zone.close();
    canvas.drawPath(
      zone,
      Paint()..color = scheme.primary.withValues(alpha: 0.18),
    );

    final ground = Path()..moveTo(0, size.height);
    for (final s in samples) {
      final p = at(s.distance, s.ground);
      ground.lineTo(p.dx, p.dy);
    }
    ground
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(ground, Paint()..color = _groundColour(scheme));

    final dash = Paint()
      ..color = scheme.primary
      ..strokeWidth = 1.5;
    for (var i = 0; i < samples.length - 1; i += 2) {
      final a = samples[i], b = samples[i + 1];
      canvas.drawLine(
        at(a.distance, a.beam - fresnelGoodRatio * a.fresnel),
        at(b.distance, b.beam - fresnelGoodRatio * b.fresnel),
        dash,
      );
    }

    canvas.drawLine(
      at(samples.first.distance, samples.first.beam),
      at(samples.last.distance, samples.last.beam),
      Paint()
        ..color = scheme.primary
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(ProfilePainter old) =>
      old.profile != profile || old.scheme != scheme;
}
