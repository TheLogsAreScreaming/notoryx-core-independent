/// On-device translation with Google's ML Kit (Android and iPhone). The
/// text never leaves the phone; only the language models are downloaded,
/// once, about 30 MB each, and only after the person agrees.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// What the app needs from a translator. Tests replace it.
abstract interface class MessageTranslator {
  /// The language of [text] as a code like "es", or null if unsure.
  Future<String?> detect(String text);

  /// Whether this device can translate to and from [code].
  bool supports(String code);

  Future<bool> hasModel(String code);

  Future<bool> download(String code);

  Future<String> translate(
    String text, {
    required String from,
    required String to,
  });
}

final class MlKitTranslator implements MessageTranslator {
  final _models = OnDeviceTranslatorModelManager();

  @override
  Future<String?> detect(String text) async {
    final id = LanguageIdentifier(confidenceThreshold: 0.5);
    try {
      final code = await id.identifyLanguage(text);
      return code == id.undeterminedLanguageCode ? null : code;
    } finally {
      await id.close();
    }
  }

  TranslateLanguage? _language(String code) =>
      TranslateLanguage.values.where((l) => l.bcpCode == code).firstOrNull;

  @override
  bool supports(String code) => _language(code) != null;

  @override
  Future<bool> hasModel(String code) => _models.isModelDownloaded(code);

  @override
  Future<bool> download(String code) =>
      _models.downloadModel(code, isWifiRequired: false);

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final t = OnDeviceTranslator(
      sourceLanguage: _language(from)!,
      targetLanguage: _language(to)!,
    );
    try {
      return await t.translateText(text);
    } finally {
      await t.close();
    }
  }
}

/// Null where on-device translation isn't available (desktop).
final translatorProvider = Provider<MessageTranslator?>(
  (ref) => Platform.isAndroid || Platform.isIOS ? MlKitTranslator() : null,
);

/// What has to happen before translating from [from] to [to].
sealed class TranslationPlan {
  const TranslationPlan();
}

final class AlreadyInLanguage extends TranslationPlan {
  const AlreadyInLanguage();
}

final class Unsupported extends TranslationPlan {
  const Unsupported();
}

final class NeedsModels extends TranslationPlan {
  const NeedsModels(this.codes);

  final List<String> codes;
}

final class Ready extends TranslationPlan {
  const Ready();
}

Future<TranslationPlan> planTranslation(
  MessageTranslator t, {
  required String? from,
  required String to,
}) async {
  if (from == null || !t.supports(from) || !t.supports(to)) {
    return const Unsupported();
  }
  if (from == to) return const AlreadyInLanguage();
  final missing = [
    for (final code in {from, to})
      if (!await t.hasModel(code)) code,
  ];
  return missing.isEmpty ? const Ready() : NeedsModels(missing);
}
