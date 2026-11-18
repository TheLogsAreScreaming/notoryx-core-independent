/// The app's language: the phone's own, or one picked in Appearance.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'connection.dart';

const languageSetting = 'app_language';

/// Languages offered, by code, with their own names. English is the
/// original; the others were written by AI.
const appLanguages = <String, String>{
  'en': 'English',
  'bg': 'Български',
  'de': 'Deutsch',
  'es': 'Español',
  'fr': 'Français',
  'hu': 'Magyar',
  'it': 'Italiano',
  'ja': '日本語',
  'ko': '한국어',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'pt': 'Português',
  'ru': 'Русский',
  'sk': 'Slovenčina',
  'sl': 'Slovenščina',
  'sv': 'Svenska',
  'uk': 'Українська',
  'zh': '中文',
};

class Language extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final code = await ref.read(storeProvider).setting(languageSetting);
    return appLanguages.containsKey(code) ? Locale(code!) : null;
  }

  /// [code] null follows the phone.
  Future<void> choose(String? code) async {
    final store = ref.read(storeProvider);
    if (code == null) {
      await store.removeSetting(languageSetting);
    } else {
      await store.saveSetting(languageSetting, code);
    }
    state = AsyncData(code == null ? null : Locale(code));
  }
}

final languageProvider = AsyncNotifierProvider<Language, Locale?>(Language.new);

/// The app's strings in its current language, for code that runs away
/// from any screen: notifications, the home widget, background notices.
final appL10nProvider = Provider<AppLocalizations>((ref) {
  final chosen = ref.watch(languageProvider).value;
  final phone = PlatformDispatcher.instance.locale;
  final locale =
      chosen ??
      (appLanguages.containsKey(phone.languageCode)
          ? Locale(phone.languageCode)
          : const Locale('en'));
  return lookupAppLocalizations(locale);
});
