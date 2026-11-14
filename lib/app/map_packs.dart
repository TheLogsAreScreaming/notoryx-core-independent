/// Offline map packs: raster MBTiles files the user brings, used for the
/// map when there's no signal. The app never bulk-downloads tiles itself
/// (the public OpenStreetMap tile servers don't allow it); packs come from
/// a tile source that permits offline use, or are made by the user.
///
/// MBTiles is a SQLite file with a `metadata` table (name/value) and a
/// `tiles` table (zoom_level, tile_column, tile_row, tile_data), rows
/// numbered from the bottom (TMS), so row = 2^zoom − 1 − y.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'connection.dart';

/// Setting holding the file name of the pack in use, or nothing.
const activeMapPackSetting = 'map_pack_active';

/// What a pack file says about itself.
typedef MapPackInfo = ({
  String fileName,
  String name,
  String format,
  int minZoom,
  int maxZoom,
  int tileCount,
  int bytes,

  /// West, south, east, north, when the pack says.
  List<double>? bounds,
  String? attribution,
});

/// Why a file can't be used as a map pack.
class MapPackException implements Exception {
  const MapPackException(this.reason);

  final MapPackProblem reason;

  @override
  String toString() => 'MapPackException($reason)';
}

enum MapPackProblem { notMbtiles, vectorTiles, empty }

/// Reads the pack at [path]. Throws [MapPackException] when it isn't a
/// raster MBTiles file with tiles in it.
MapPackInfo readMapPack(String path) {
  final Database db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
  } on Object {
    throw const MapPackException(MapPackProblem.notMbtiles);
  }
  try {
    final meta = <String, String>{};
    try {
      for (final row in db.select('SELECT name, value FROM metadata')) {
        meta['${row['name']}'] = '${row['value']}';
      }
    } on SqliteException {
      throw const MapPackException(MapPackProblem.notMbtiles);
    }
    final format = (meta['format'] ?? 'png').toLowerCase();
    if (format == 'pbf' || format == 'mvt') {
      throw const MapPackException(MapPackProblem.vectorTiles);
    }
    if (!const {'png', 'jpg', 'jpeg', 'webp'}.contains(format)) {
      throw const MapPackException(MapPackProblem.notMbtiles);
    }
    final ResultSet stats;
    try {
      stats = db.select(
        'SELECT COUNT(*) AS n, MIN(zoom_level) AS lo, MAX(zoom_level) AS hi '
        'FROM tiles',
      );
    } on SqliteException {
      throw const MapPackException(MapPackProblem.notMbtiles);
    }
    final count = stats.first['n'] as int;
    if (count == 0) throw const MapPackException(MapPackProblem.empty);
    final bounds = meta['bounds']
        ?.split(',')
        .map((s) => double.tryParse(s.trim()))
        .toList();
    return (
      fileName: p.basename(path),
      name: (meta['name']?.trim().isNotEmpty ?? false)
          ? meta['name']!.trim()
          : p.basenameWithoutExtension(path),
      format: format,
      minZoom: stats.first['lo'] as int,
      maxZoom: stats.first['hi'] as int,
      tileCount: count,
      bytes: File(path).lengthSync(),
      bounds: bounds != null && bounds.length == 4 && !bounds.contains(null)
          ? bounds.cast<double>()
          : null,
      attribution: meta['attribution'],
    );
  } finally {
    db.close();
  }
}

/// Folder the packs are kept in. Tests replace this.
final mapPackDirProvider = FutureProvider<Directory>((ref) async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'map_packs')).create(recursive: true);
});

/// Asks for a pack file to import. Returns its path, or null if the user
/// backed out. Tests replace this.
final mapPackPickerProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final picked = await FilePicker.pickFile(dialogTitle: 'Import map pack');
    return picked?.path;
  },
);

/// The packs that have been imported, by name.
final mapPacksProvider = FutureProvider<List<MapPackInfo>>((ref) async {
  final dir = await ref.watch(mapPackDirProvider.future);
  final out = <MapPackInfo>[];
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.toLowerCase().endsWith('.mbtiles')) continue;
    try {
      out.add(readMapPack(f.path));
    } on MapPackException {
      // A damaged file: leave it out of the list.
    }
  }
  return out..sort((a, b) => a.name.compareTo(b.name));
});

/// The file name of the pack in use, or null.
final activeMapPackProvider = StreamProvider<String?>(
  (ref) => ref
      .watch(storeProvider)
      .watchSettingsWithPrefix(activeMapPackSetting)
      .map((m) => m['']),
);

/// Full path of the pack in use, or null when none is chosen or its file
/// is gone.
final activeMapPackPathProvider = FutureProvider<String?>((ref) async {
  final name = await ref.watch(activeMapPackProvider.future);
  if (name == null) return null;
  final dir = await ref.watch(mapPackDirProvider.future);
  final path = p.join(dir.path, name);
  return File(path).existsSync() ? path : null;
});

/// Uses the pack named [fileName] for the map, or none when null.
Future<void> chooseMapPack(WidgetRef ref, String? fileName) {
  final store = ref.read(storeProvider);
  return fileName == null
      ? store.removeSetting(activeMapPackSetting)
      : store.saveSetting(activeMapPackSetting, fileName);
}

/// Deletes an imported pack, and stops using it if it was in use.
Future<void> deleteMapPack(WidgetRef ref, String fileName) async {
  final dir = await ref.read(mapPackDirProvider.future);
  if (ref.read(activeMapPackProvider).value == fileName) {
    await chooseMapPack(ref, null);
  }
  final file = File(p.join(dir.path, fileName));
  if (file.existsSync()) await file.delete();
  ref.invalidate(mapPacksProvider);
}

/// Copies the pack at [source] into the packs folder and checks it.
/// Returns its info. Throws [MapPackException] and keeps nothing if it
/// can't be used.
Future<MapPackInfo> importMapPack(Directory dir, String source) async {
  // Check before copying, so a wrong file isn't copied at all.
  readMapPack(source);
  var name = p.basename(source);
  if (!name.toLowerCase().endsWith('.mbtiles')) name = '$name.mbtiles';
  var target = p.join(dir.path, name);
  for (var i = 2; File(target).existsSync(); i++) {
    target = p.join(
      dir.path,
      '${p.basenameWithoutExtension(name)} ($i).mbtiles',
    );
  }
  await File(source).copy(target);
  return readMapPack(target);
}

/// Serves tiles from a pack where it has them, and from [fallback] (the
/// saved online tiles) everywhere else.
class MapPackTileProvider extends TileProvider {
  MapPackTileProvider(String path, this.fallback)
    : _db = sqlite3.open(path, mode: OpenMode.readOnly);

  final TileProvider fallback;
  final Database _db;
  late final _query = _db.prepare(
    'SELECT tile_data FROM tiles '
    'WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
  );

  /// The pack's tile at [c], or null when it has none.
  Uint8List? tile(TileCoordinates c) {
    final row = (1 << c.z) - 1 - c.y;
    final rows = _query.select([c.z, c.x, row]);
    if (rows.isEmpty) return null;
    return rows.first['tile_data'] as Uint8List;
  }

  @override
  bool get supportsCancelLoading => fallback.supportsCancelLoading;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final bytes = tile(coordinates);
    return bytes == null
        ? fallback.getImage(coordinates, options)
        : MemoryImage(bytes);
  }

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    final bytes = tile(coordinates);
    return bytes == null
        ? fallback.getImageWithCancelLoadingSupport(
            coordinates,
            options,
            cancelLoading,
          )
        : MemoryImage(bytes);
  }

  @override
  void dispose() {
    _query.close();
    _db.close();
    fallback.dispose();
    super.dispose();
  }
}
