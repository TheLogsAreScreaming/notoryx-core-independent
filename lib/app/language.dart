/// The app's language: the phone's own, or one picked in Appearance.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';

const languageSetting = 'app_language';

/// Languages offered, by code, with their own names. English is the
/// original; the others were written by AI.
const appLanguages = <String, String>{'en': 'English', 'es': 'Español'};

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
