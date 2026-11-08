/// The app's theme and chat text size, kept in the database.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';

/// The themes on offer.
enum AppThemeChoice {
  automatic('Automatic', 'Follows your phone'),
  light('Light', 'Always light'),
  dark('Dark', 'Always dark'),
  trail('Trail', 'Forest green'),
  lake('Lake', 'Deep blue'),
  night('Night', 'Red on black, to protect night vision'),
  highContrast('High contrast', 'Strongest text and edges'),
  colourSafe('Colour-blind safe', 'Blue and orange, never red against green');

  const AppThemeChoice(this.label, this.description);

  final String label;
  final String description;

  /// Whether the phone's light or dark mode decides, or this theme does.
  ThemeMode get mode => switch (this) {
    AppThemeChoice.light => ThemeMode.light,
    AppThemeChoice.dark || AppThemeChoice.night => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

const _ember = Color(0xFFE8721C);

/// The colours for [choice] in [brightness].
ColorScheme schemeFor(AppThemeChoice choice, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  ColorScheme seeded(Color seed) =>
      ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  return switch (choice) {
    AppThemeChoice.automatic ||
    AppThemeChoice.light ||
    AppThemeChoice.dark => seeded(_ember),
    AppThemeChoice.trail => seeded(const Color(0xFF2E7D32)),
    AppThemeChoice.lake => seeded(const Color(0xFF1565C0)),
    AppThemeChoice.night => const ColorScheme.dark(
      primary: Color(0xFFFF6B5E),
      onPrimary: Color(0xFF000000),
      primaryContainer: Color(0xFF5A0F0A),
      onPrimaryContainer: Color(0xFFFFB4AB),
      secondary: Color(0xFFE57368),
      onSecondary: Color(0xFF000000),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFFF9C92),
      onSurfaceVariant: Color(0xFFE57368),
      surfaceContainerHighest: Color(0xFF2A0705),
      outline: Color(0xFFB0473D),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF000000),
    ),
    // Flutter's dark version pairs its error colours too weakly for text.
    AppThemeChoice.highContrast =>
      dark
          ? const ColorScheme.highContrastDark().copyWith(
              error: const Color(0xFFFFB4AB),
              onError: const Color(0xFF000000),
            )
          : const ColorScheme.highContrastLight(),
    // Okabe-Ito blue and vermilion, darkened or lightened until text on
    // them is readable.
    AppThemeChoice.colourSafe => seeded(const Color(0xFF0072B2)).copyWith(
      error: dark ? const Color(0xFFFFB68F) : const Color(0xFFA84300),
      onError: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
    ),
  };
}

/// The whole app theme for [choice] in [brightness].
ThemeData themeFor(AppThemeChoice choice, Brightness brightness) =>
    ThemeData(colorScheme: schemeFor(choice, brightness));

/// The theme and chat text size in use.
typedef Appearance = ({AppThemeChoice theme, double chatScale});

const themeSetting = 'app_theme';
const chatScaleSetting = 'chat_text_scale';

/// The chat text sizes on offer, as multiples of the normal size.
const chatScales = [0.85, 1.0, 1.15, 1.3, 1.5, 1.8];

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(
  AppearanceNotifier.new,
);

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() {
    unawaited(_load());
    return (theme: AppThemeChoice.automatic, chatScale: 1.0);
  }

  Future<void> _load() async {
    final store = ref.read(storeProvider);
    final theme = await store.setting(themeSetting);
    final scale = await store.setting(chatScaleSetting);
    if (!ref.mounted) return;
    state = (
      theme: AppThemeChoice.values.asNameMap()[theme] ?? state.theme,
      chatScale: double.tryParse(scale ?? '') ?? state.chatScale,
    );
  }

  Future<void> setTheme(AppThemeChoice theme) async {
    state = (theme: theme, chatScale: state.chatScale);
    await ref.read(storeProvider).saveSetting(themeSetting, theme.name);
  }

  Future<void> setChatScale(double scale) async {
    state = (theme: state.theme, chatScale: scale);
    await ref.read(storeProvider).saveSetting(chatScaleSetting, '$scale');
  }
}
