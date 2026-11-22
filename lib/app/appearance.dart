/// The app's theme and chat text size, kept in the database.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'connection.dart';

/// The themes on offer. [blackout] is the default.
///
/// Light, Dark, Night and Lake were removed; a saved choice that no longer
/// exists falls back to [blackout] when it is loaded.
enum AppThemeChoice {
  blackout,
  automatic,
  trail,
  highContrast,
  colourSafe;

  /// The theme's name in the app's language.
  String label(AppLocalizations l10n) => switch (this) {
    blackout => l10n.themeBlackout,
    automatic => l10n.themeAutomatic,
    trail => l10n.themeTrail,
    highContrast => l10n.themeHighContrast,
    colourSafe => l10n.themeColourSafe,
  };

  /// One line on what the theme looks like.
  String description(AppLocalizations l10n) => switch (this) {
    blackout => l10n.themeBlackoutNote,
    automatic => l10n.themeAutomaticNote,
    trail => l10n.themeTrailNote,
    highContrast => l10n.themeHighContrastNote,
    colourSafe => l10n.themeColourSafeNote,
  };

  /// Whether the phone's light or dark mode decides, or this theme does.
  ThemeMode get mode => switch (this) {
    AppThemeChoice.blackout => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

const _ember = Color(0xFFE8721C);

/// The NOTORYX BLACKOUT palette.
const _matte = Color(0xFF080808);
const _charcoal = Color(0xFF242424);
const _gunmetal = Color(0xFF484848);
const _steel = Color(0xFF888888);
const _frost = Color(0xFFE8E8E8);

/// Steel lifted just enough for secondary text to stay readable (4.5:1) on
/// charcoal cards; plain [_steel] is only 4.3:1 there.
const _steelText = Color(0xFF9A9A9A);

/// Monochrome BLACKOUT colours. Errors stay red and cautions amber: they
/// carry meaning.
const _blackout = ColorScheme(
  brightness: Brightness.dark,
  primary: _frost,
  onPrimary: _matte,
  primaryContainer: _gunmetal,
  onPrimaryContainer: _frost,
  secondary: _steel,
  onSecondary: _matte,
  secondaryContainer: _charcoal,
  onSecondaryContainer: _frost,
  // Amber, not grey: screens use tertiary for "fair" signal, partly
  // blocked paths and mentions, between frost (good) and red (bad).
  tertiary: Color(0xFFFFB951),
  onTertiary: _matte,
  tertiaryContainer: Color(0xFF3D2E00),
  onTertiaryContainer: Color(0xFFFFE08A),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF000000),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: _matte,
  onSurface: _frost,
  onSurfaceVariant: _steelText,
  surfaceDim: _matte,
  surfaceBright: Color(0xFF2E2E2E),
  surfaceContainerLowest: _matte,
  surfaceContainerLow: Color(0xFF121212),
  surfaceContainer: Color(0xFF181818),
  surfaceContainerHigh: Color(0xFF1E1E1E),
  surfaceContainerHighest: _charcoal,
  outline: _steel,
  outlineVariant: _gunmetal,
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: _frost,
  onInverseSurface: _matte,
  inversePrimary: _gunmetal,
  surfaceTint: Color(0x00000000),
);

/// The colours for [choice] in [brightness].
ColorScheme schemeFor(AppThemeChoice choice, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  ColorScheme seeded(Color seed) =>
      ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  return switch (choice) {
    // Always dark, whatever the phone says.
    AppThemeChoice.blackout => _blackout,
    AppThemeChoice.automatic => seeded(_ember),
    AppThemeChoice.trail => seeded(const Color(0xFF2E7D32)),
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
    return (theme: AppThemeChoice.blackout, chatScale: 1.0);
  }

  Future<void> _load() async {
    final store = ref.read(storeProvider);
    final theme = await store.setting(themeSetting);
    final scale = await store.setting(chatScaleSetting);
    if (!ref.mounted) return;
    state = (
      // A theme that was removed (light, dark, night, lake) or junk falls
      // back to BLACKOUT.
      theme:
          AppThemeChoice.values.asNameMap()[theme] ?? AppThemeChoice.blackout,
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
