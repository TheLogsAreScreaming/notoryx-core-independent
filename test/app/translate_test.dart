import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/translate.dart';

final class _Fake implements MessageTranslator {
  _Fake(this.models);

  final Set<String> models;

  @override
  bool supports(String code) => {'en', 'es', 'de'}.contains(code);

  @override
  Future<bool> hasModel(String code) async => models.contains(code);

  @override
  Future<String?> detect(String text) async => null;

  @override
  Future<bool> download(String code) async => models.add(code);

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async => text;
}

void main() {
  test('same language needs nothing', () async {
    expect(
      await planTranslation(_Fake({}), from: 'en', to: 'en'),
      isA<AlreadyInLanguage>(),
    );
  });

  test('unknown or unsupported languages are refused', () async {
    expect(
      await planTranslation(_Fake({}), from: null, to: 'en'),
      isA<Unsupported>(),
    );
    expect(
      await planTranslation(_Fake({}), from: 'xx', to: 'en'),
      isA<Unsupported>(),
    );
  });

  test('missing models are listed, and none when both are present', () async {
    final plan = await planTranslation(_Fake({'en'}), from: 'es', to: 'en');
    expect((plan as NeedsModels).codes, ['es']);
    final both = await planTranslation(_Fake({}), from: 'es', to: 'de');
    expect((both as NeedsModels).codes, ['es', 'de']);
    expect(
      await planTranslation(_Fake({'en', 'es'}), from: 'es', to: 'en'),
      isA<Ready>(),
    );
  });
}
