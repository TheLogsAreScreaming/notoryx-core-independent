import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_background.dart';

/// How the glass cards over a custom background should look, or null when
/// the theme's own background is in use.
typedef GlassStyle = ({double fill, bool blur, Color surface});

/// Works out the glass style for the background in use.
GlassStyle? glassStyleOf(BuildContext context, WidgetRef ref) {
  final bg = ref.watch(appBackgroundProvider);
  if (!bg.isCustom) return null;
  final scheme = Theme.of(context).colorScheme;
  final blur =
      !MediaQuery.disableAnimationsOf(context) &&
      !(ref.watch(powerSaveProvider).value ?? false);
  return (
    fill: glassFillOpacity(
      samples: backgroundSamples(bg),
      surface: scheme.surface,
      text: scheme.onSurface,
      blurred: blur,
    ),
    blur: blur,
    surface: scheme.surface,
  );
}

/// Draws the chosen background behind [child], and makes the scaffold
/// inside see-through so it shows. With the theme background, [child] is
/// returned as it is.
class BackgroundLayer extends ConsumerStatefulWidget {
  const BackgroundLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends ConsumerState<BackgroundLayer> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Power saving may have been turned on or off while away.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(powerSaveProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = ref.watch(appBackgroundProvider);
    if (!bg.isCustom) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    final dim = readableDim(
      chosen: bg.dim,
      samples: backgroundSamples(bg),
      surface: scheme.surface,
      text: scheme.onSurface,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(child: BackgroundPaint(background: bg)),
        ColoredBox(color: scheme.surface.withValues(alpha: dim)),
        BackdropGroup(
          child: Theme(
            data: Theme.of(context)
                .copyWith(scaffoldBackgroundColor: Colors.transparent),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// The background itself, without dimming.
class BackgroundPaint extends StatelessWidget {
  const BackgroundPaint({super.key, required this.background});

  final AppBackground background;

  @override
  Widget build(BuildContext context) {
    final bg = background;
    return switch (bg.kind) {
      BackgroundKind.theme => const SizedBox.expand(),
      BackgroundKind.solid => ColoredBox(color: bg.first),
      BackgroundKind.gradient => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg.first, bg.second],
          ),
        ),
      ),
      BackgroundKind.mesh => _Mesh(first: bg.first, second: bg.second),
      BackgroundKind.photo => switch (bg.photoPath) {
        null => const SizedBox.expand(),
        final path => ImageFiltered(
          enabled: bg.blur > 0,
          imageFilter: ImageFilter.blur(
            sigmaX: bg.blur,
            sigmaY: bg.blur,
            tileMode: TileMode.mirror,
          ),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        ),
      },
    };
  }
}

/// Soft overlapping glows of two colours and their blend.
class _Mesh extends StatelessWidget {
  const _Mesh({required this.first, required this.second});

  final Color first;
  final Color second;

  @override
  Widget build(BuildContext context) {
    final mid = Color.lerp(first, second, 0.5)!;
    Widget glow(Alignment at, Color colour, double radius) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: at,
          radius: radius,
          colors: [colour, colour.withValues(alpha: 0)],
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: mid),
        glow(const Alignment(-0.9, -0.8), first, 1.1),
        glow(const Alignment(0.9, 0.9), second, 1.1),
        glow(const Alignment(0.8, -0.9), Color.lerp(mid, first, 0.3)!, 0.8),
        glow(const Alignment(-0.8, 0.8), Color.lerp(mid, second, 0.3)!, 0.8),
      ],
    );
  }
}

/// A frosted-glass card over a custom background; with the theme
/// background it gives back [child] as it is.
class GlassCard extends ConsumerWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = glassStyleOf(context, ref);
    if (style == null) return child;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: style.surface.withValues(alpha: style.fill),
        borderRadius: radius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: style.blur
            ? BackdropFilter.grouped(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: card,
              )
            : card,
      ),
    );
  }
}
