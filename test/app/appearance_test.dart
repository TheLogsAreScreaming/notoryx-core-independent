import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/appearance.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/data/data.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

void main() {
  for (final choice in AppThemeChoice.values) {
    for (final brightness in Brightness.values) {
      test('${choice.name} ${brightness.name} text is readable', () {
        final s = schemeFor(choice, brightness);
        expect(_contrast(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
        expect(_contrast(s.onError, s.error), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(s.onPrimaryContainer, s.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  }

  test('the choice survives a restart', () async {
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    ProviderContainer open() =>
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    final first = open();
    addTearDown(first.dispose);
    first.read(appearanceProvider);
    await first
        .read(appearanceProvider.notifier)
        .setTheme(AppThemeChoice.trail);
    await first.read(appearanceProvider.notifier).setChatScale(1.3);

    final second = open();
    addTearDown(second.dispose);
    second.read(appearanceProvider);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(second.read(appearanceProvider).theme, AppThemeChoice.trail);
    expect(second.read(appearanceProvider).chatScale, 1.3);
  });

  test('BLACKOUT secondary text is readable on cards', () {
    final s = schemeFor(AppThemeChoice.blackout, Brightness.dark);
    expect(
      _contrast(s.onSurfaceVariant, s.surfaceContainerHighest),
      greaterThanOrEqualTo(4.5),
    );
    expect(_contrast(s.onSurfaceVariant, s.surface), greaterThanOrEqualTo(4.5));
    expect(
      _contrast(s.onSecondaryContainer, s.secondaryContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(_contrast(s.onTertiary, s.tertiary), greaterThanOrEqualTo(4.5));
    expect(
      _contrast(s.onTertiaryContainer, s.tertiaryContainer),
      greaterThanOrEqualTo(4.5),
    );
    // Caution and error stay coloured, not grey.
    for (final c in [s.tertiary, s.error]) {
      final hsl = HSLColor.fromColor(c);
      expect(hsl.saturation, greaterThan(0.5));
    }
    expect(AppThemeChoice.blackout.mode, ThemeMode.dark);
  });

  Future<AppThemeChoice> loadWith(String? saved) async {
    final db = MeshDatabase.inMemory();
    addTearDown(db.close);
    if (saved != null) await MeshStore(db).saveSetting(themeSetting, saved);
    final c = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    c.read(appearanceProvider);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return c.read(appearanceProvider).theme;
  }

  test('BLACKOUT is the default on a fresh install', () async {
    expect(await loadWith(null), AppThemeChoice.blackout);
  });

  test('a removed or unknown saved theme falls back to BLACKOUT', () async {
    for (final gone in ['light', 'dark', 'night', 'lake', 'nonsense']) {
      expect(await loadWith(gone), AppThemeChoice.blackout, reason: gone);
    }
  });

  test('a kept saved theme still loads', () async {
    expect(await loadWith('automatic'), AppThemeChoice.automatic);
  });
}
