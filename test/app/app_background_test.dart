import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:notoryx_core/app/app_background.dart';
import 'package:notoryx_core/app/appearance.dart';

void main() {
  test('settings survive encoding, and junk falls back to the theme', () {
    const bg = AppBackground(
      kind: BackgroundKind.mesh,
      first: Color(0xFF6A1B9A),
      second: Color(0xFF00897B),
      dim: 0.5,
      blur: 4,
    );
    expect(AppBackground.decode(bg.encode()), bg);
    expect(AppBackground.decode(null).kind, BackgroundKind.theme);
    expect(AppBackground.decode('nope').kind, BackgroundKind.theme);
    expect(AppBackground.decode('{"dim": 9}').dim, maxDim);
  });

  test('a photo background without a photo is not custom', () {
    expect(const AppBackground(kind: BackgroundKind.photo).isCustom, isFalse);
    expect(
      const AppBackground(
        kind: BackgroundKind.photo,
        photoPath: '/x.jpg',
      ).isCustom,
      isTrue,
    );
    expect(const AppBackground().isCustom, isFalse);
  });

  test('contrastRatio matches the WCAG extremes', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(contrastRatio(Colors.red, Colors.red), closeTo(1, 0.001));
  });

  test('text keeps 4.5:1 over every background in every theme', () {
    for (final choice in AppThemeChoice.values) {
      for (final brightness in Brightness.values) {
        final scheme = schemeFor(choice, brightness);
        for (final first in backgroundColours) {
          for (final kind in BackgroundKind.values.skip(1)) {
            final bg = AppBackground(
              kind: kind,
              first: first,
              second: backgroundColours.last,
              photoPath: '/x.jpg',
              dim: 0,
            );
            final samples = backgroundSamples(bg);
            final dim = readableDim(
              chosen: bg.dim,
              samples: samples,
              surface: scheme.surface,
              text: scheme.onSurface,
            );
            for (final blurred in [true, false]) {
              final fill = glassFillOpacity(
                samples: samples,
                surface: scheme.surface,
                text: scheme.onSurface,
                blurred: blurred,
              );
              for (final s in samples) {
                final behind = Color.lerp(s, scheme.surface, dim)!;
                final glass = Color.lerp(behind, scheme.surface, fill)!;
                expect(
                  contrastRatio(scheme.onSurface, behind),
                  greaterThanOrEqualTo(4.5),
                  reason: '$choice $brightness $kind $s behind',
                );
                expect(
                  contrastRatio(scheme.onSurface, glass),
                  greaterThanOrEqualTo(4.5),
                  reason: '$choice $brightness $kind $s glass',
                );
              }
            }
          }
        }
      }
    }
  });

  test('readableDim never lowers what was chosen', () {
    expect(
      readableDim(
        chosen: 0.7,
        samples: const [Color(0xFFFFFFFF)],
        surface: const Color(0xFFFFFFFF),
        text: const Color(0xFF000000),
      ),
      0.7,
    );
  });

  test('backgroundJpeg shrinks big pictures and refuses others', () {
    final big = img.Image(width: 4000, height: 1000);
    final out = img.decodeJpg(
      backgroundJpeg(Uint8List.fromList(img.encodePng(big)))!,
    )!;
    expect(out.width, backgroundPhotoSide);
    expect(out.height, 480);
    expect(backgroundJpeg(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
