import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/refresh_rate.dart';
import 'package:notoryx_core/l10n/l10n.dart';

void main() {
  test('refresh rate summary has clean punctuation in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final rate in RefreshRate.values) {
        final text = l10n.rateSummary(rate.label(l10n), rate.detail(l10n));
        expect(text, isNot(contains('..')), reason: '$locale $rate');
        expect(text, isNot(contains('。.')), reason: '$locale $rate');
        expect(text, isNot(contains('.。')), reason: '$locale $rate');
      }
    }
  });

  test('English and Japanese summaries read naturally', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      en.rateSummary(
        RefreshRate.normal.label(en),
        RefreshRate.normal.detail(en),
      ),
      'Normal. Sensors every 30 min, noise floor every 10 min.',
    );
    final ja = lookupAppLocalizations(const Locale('ja'));
    expect(
      ja.rateSummary(
        RefreshRate.normal.label(ja),
        RefreshRate.normal.detail(ja),
      ),
      '標準。センサー30分ごと、ノイズフロア10分ごと。',
    );
  });
}
