import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/map_packs.dart';
import 'package:sqlite3/sqlite3.dart';

/// Writes a small raster MBTiles file with one tile per [tiles] entry
/// (z, x, y in map numbering).
String makePack(
  Directory dir,
  String name, {
  String format = 'png',
  List<(int, int, int)> tiles = const [(3, 2, 1)],
  Map<String, String> meta = const {},
}) {
  final path = '${dir.path}/$name';
  final db = sqlite3.open(path);
  db
    ..execute('CREATE TABLE metadata (name TEXT, value TEXT)')
    ..execute(
      'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, '
      'tile_row INTEGER, tile_data BLOB)',
    );
  for (final e in {'name': 'Ridge', 'format': format, ...meta}.entries) {
    db.execute('INSERT INTO metadata VALUES (?, ?)', [e.key, e.value]);
  }
  for (final (z, x, y) in tiles) {
    db.execute('INSERT INTO tiles VALUES (?, ?, ?, ?)', [
      z,
      x,
      (1 << z) - 1 - y,
      Uint8List.fromList([z, x, y]),
    ]);
  }
  db.close();
  return path;
}

class _Fallback extends TileProvider {
  int asked = 0;
  bool disposed = false;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    asked++;
    return MemoryImage(Uint8List(0));
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('packs'));
  tearDown(() => dir.delete(recursive: true));

  test('a raster pack is read: name, zooms, tiles and bounds', () {
    final path = makePack(
      dir,
      'ridge.mbtiles',
      tiles: [(3, 2, 1), (5, 8, 9)],
      meta: {'bounds': '-81.0, 35.0, -80.5, 35.5', 'attribution': 'Me'},
    );
    final info = readMapPack(path);
    expect(info.name, 'Ridge');
    expect(info.minZoom, 3);
    expect(info.maxZoom, 5);
    expect(info.tileCount, 2);
    expect(info.bounds, [-81.0, 35.0, -80.5, 35.5]);
    expect(info.attribution, 'Me');
  });

  test('vector, empty and non-MBTiles files are refused', () {
    Matcher problem(MapPackProblem p) =>
        throwsA(isA<MapPackException>().having((e) => e.reason, 'reason', p));
    expect(
      () => readMapPack(makePack(dir, 'v.mbtiles', format: 'pbf')),
      problem(MapPackProblem.vectorTiles),
    );
    expect(
      () => readMapPack(makePack(dir, 'e.mbtiles', tiles: [])),
      problem(MapPackProblem.empty),
    );
    final text = File('${dir.path}/notes.txt')..writeAsStringSync('hello');
    expect(() => readMapPack(text.path), problem(MapPackProblem.notMbtiles));
  });

  test('import copies the file, never over an existing pack', () async {
    final source = await Directory.systemTemp.createTemp('src');
    addTearDown(() => source.delete(recursive: true));
    final path = makePack(source, 'ridge.mbtiles');
    final first = await importMapPack(dir, path);
    final second = await importMapPack(dir, path);
    expect(first.fileName, 'ridge.mbtiles');
    expect(second.fileName, 'ridge (2).mbtiles');
    expect(File(path).existsSync(), isTrue);
  });

  test('a bad file is not copied in', () async {
    final source = await Directory.systemTemp.createTemp('src');
    addTearDown(() => source.delete(recursive: true));
    final bad = makePack(source, 'v.mbtiles', format: 'pbf');
    await expectLater(
      importMapPack(dir, bad),
      throwsA(isA<MapPackException>()),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('tiles come from the pack (rows flipped), others from online', () {
    final path = makePack(dir, 'ridge.mbtiles', tiles: [(3, 2, 1)]);
    final fallback = _Fallback();
    final provider = MapPackTileProvider(path, fallback);
    expect(provider.tile(const TileCoordinates(2, 1, 3)), [3, 2, 1]);
    expect(provider.tile(const TileCoordinates(2, 6, 3)), isNull);
    final layer = TileLayer(urlTemplate: 'x');
    expect(
      provider.getImage(const TileCoordinates(2, 1, 3), layer),
      isA<MemoryImage>(),
    );
    expect(fallback.asked, 0);
    provider.getImage(const TileCoordinates(0, 0, 3), layer);
    expect(fallback.asked, 1);
    provider.dispose();
    expect(fallback.disposed, isTrue);
  });
}
