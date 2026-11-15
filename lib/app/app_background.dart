/// The picture or colours behind the main screens, and the sums that keep
/// text readable over them.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'connection.dart';

/// What sits behind the main screens.
enum BackgroundKind {
  /// The theme's own surface colour, as before.
  theme,

  /// One colour.
  solid,

  /// Two colours, corner to corner.
  gradient,

  /// Soft blobs of two colours and a blend of them.
  mesh,

  /// The person's own photo.
  photo,
}

/// The background setting.
@immutable
class AppBackground {
  const AppBackground({
    this.kind = BackgroundKind.theme,
    this.first = const Color(0xFF1565C0),
    this.second = const Color(0xFF00897B),
    this.photoPath,
    this.dim = 0.35,
    this.blur = 0,
  });

  final BackgroundKind kind;
  final Color first;
  final Color second;

  /// Where the copied photo is kept, for [BackgroundKind.photo].
  final String? photoPath;

  /// How much the theme's surface colour is laid over it, 0 to [maxDim].
  final double dim;

  /// How much a photo is blurred, 0 to [maxBlur].
  final double blur;

  /// Whether anything other than the theme's surface shows.
  bool get isCustom =>
      kind != BackgroundKind.theme &&
      (kind != BackgroundKind.photo || photoPath != null);

  AppBackground copyWith({
    BackgroundKind? kind,
    Color? first,
    Color? second,
    String? photoPath,
    double? dim,
    double? blur,
  }) => AppBackground(
    kind: kind ?? this.kind,
    first: first ?? this.first,
    second: second ?? this.second,
    photoPath: photoPath ?? this.photoPath,
    dim: dim ?? this.dim,
    blur: blur ?? this.blur,
  );

  String encode() => jsonEncode({
    'kind': kind.name,
    'first': first.toARGB32(),
    'second': second.toARGB32(),
    'photo': ?photoPath,
    'dim': dim,
    'blur': blur,
  });

  static AppBackground decode(String? raw) {
    if (raw == null) return const AppBackground();
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return const AppBackground();
      return AppBackground(
        kind:
            BackgroundKind.values.asNameMap()[map['kind']] ??
            BackgroundKind.theme,
        first: Color((map['first'] as num?)?.toInt() ?? 0xFF1565C0),
        second: Color((map['second'] as num?)?.toInt() ?? 0xFF00897B),
        photoPath: map['photo'] as String?,
        dim: ((map['dim'] as num?)?.toDouble() ?? 0.35).clamp(0, maxDim),
        blur: ((map['blur'] as num?)?.toDouble() ?? 0).clamp(0, maxBlur),
      );
    } on Object {
      return const AppBackground();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AppBackground && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

const maxDim = 0.85;
const maxBlur = 20.0;
const backgroundSetting = 'app_background';

/// Colours offered for solid and gradient backgrounds.
const backgroundColours = <Color>[
  Color(0xFF0D47A1), // deep blue
  Color(0xFF1565C0), // blue
  Color(0xFF00897B), // teal
  Color(0xFF2E7D32), // green
  Color(0xFF827717), // olive
  Color(0xFFEF6C00), // orange
  Color(0xFFC62828), // red
  Color(0xFFAD1457), // pink
  Color(0xFF6A1B9A), // purple
  Color(0xFF37474F), // slate
  Color(0xFF212121), // charcoal
  Color(0xFFECEFF1), // mist
];

/// WCAG contrast ratio between two opaque colours, 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The colours a background can show at its brightest and darkest, used to
/// check text against it. A photo can be anything, so it counts as both
/// black and white.
List<Color> backgroundSamples(AppBackground bg) => switch (bg.kind) {
  BackgroundKind.theme => const [],
  BackgroundKind.solid => [bg.first],
  BackgroundKind.gradient || BackgroundKind.mesh => [
    bg.first,
    bg.second,
    Color.lerp(bg.first, bg.second, 0.5)!,
  ],
  BackgroundKind.photo => const [Color(0xFF000000), Color(0xFFFFFFFF)],
};

/// The least dimming, at or above [chosen], that keeps [text] at 4.5:1
/// against every sample once [surface] is laid over it.
double readableDim({
  required double chosen,
  required List<Color> samples,
  required Color surface,
  required Color text,
}) {
  bool readable(double dim) => samples.every(
    (s) => contrastRatio(text, Color.lerp(s, surface, dim)!) >= 4.5,
  );
  var dim = chosen.clamp(0.0, 1.0);
  while (dim < 1 && !readable(dim)) {
    dim = math.min(1, dim + 0.01);
  }
  return dim;
}

/// Opacity of the glass fill on cards. Cards keep 4.5:1 for [text] over
/// any sample on their own, even without the dimming.
double glassFillOpacity({
  required List<Color> samples,
  required Color surface,
  required Color text,
  required bool blurred,
}) => readableDim(
  // Without blur the glass is close to solid so busy pictures don't show
  // through sharply.
  chosen: blurred ? 0.6 : 0.88,
  samples: samples,
  surface: surface,
  text: text,
);

final appBackgroundProvider =
    NotifierProvider<AppBackgroundNotifier, AppBackground>(
      AppBackgroundNotifier.new,
    );

class AppBackgroundNotifier extends Notifier<AppBackground> {
  @override
  AppBackground build() {
    unawaited(_load());
    return const AppBackground();
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(backgroundSetting);
    if (!ref.mounted || raw == null) return;
    var loaded = AppBackground.decode(raw);
    final photo = loaded.photoPath;
    if (photo != null && !File(photo).existsSync()) {
      loaded = AppBackground(
        kind: loaded.kind == BackgroundKind.photo
            ? BackgroundKind.theme
            : loaded.kind,
        first: loaded.first,
        second: loaded.second,
        dim: loaded.dim,
        blur: loaded.blur,
      );
    }
    state = loaded;
  }

  Future<void> set(AppBackground value) async {
    state = value;
    await ref
        .read(storeProvider)
        .saveSetting(backgroundSetting, value.encode());
  }

  /// Copies [jpeg] in as the background photo and switches to it.
  Future<void> usePhoto(Uint8List jpeg) async {
    final dir = await ref.read(backgroundDirProvider)();
    final old = state.photoPath;
    final file = File(
      p.join(
        dir.path,
        'background-${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );
    await file.writeAsBytes(jpeg, flush: true);
    await set(state.copyWith(kind: BackgroundKind.photo, photoPath: file.path));
    if (old != null && old != file.path) {
      try {
        await File(old).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }
}

/// Where background photos are kept. Tests replace this.
final backgroundDirProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final dir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'backgrounds'),
    );
    await dir.create(recursive: true);
    return dir;
  },
);

/// Longest side, in pixels, a background photo is kept at.
const backgroundPhotoSide = 1920;

/// [source] shrunk to fit [backgroundPhotoSide] as a JPEG, or null if it
/// isn't a picture.
Uint8List? backgroundJpeg(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final longest = math.max(upright.width, upright.height);
  final fitted = longest <= backgroundPhotoSide
      ? upright
      : img.copyResize(
          upright,
          width: upright.width >= upright.height ? backgroundPhotoSide : null,
          height: upright.height > upright.width ? backgroundPhotoSide : null,
          interpolation: img.Interpolation.average,
        );
  return Uint8List.fromList(img.encodeJpg(fitted, quality: 85));
}

/// Asks for a gallery picture; null if none was picked, empty if it
/// couldn't be read. Tests replace this.
final backgroundPhotoPickerProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return await Isolate.run(() => backgroundJpeg(bytes)) ?? Uint8List(0);
  },
);

/// Whether the phone is saving power, so blur effects should stay off.
/// Tests replace this.
final powerSaveProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return false;
  try {
    return await const MethodChannel('notoryx/keep_alive')
            .invokeMethod<bool>('powerSave') ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
});
