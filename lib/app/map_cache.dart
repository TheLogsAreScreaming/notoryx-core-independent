import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// How long a map tile is used before asking the server whether it changed.
/// Longer than the tile server's own headers so places you've looked at
/// keep working with no signal: offline, a stale tile isn't shown at all.
const mapTileFreshFor = Duration(days: 30);

/// Room the saved map tiles may take.
const mapCacheBytes = 500 * 1000 * 1000;

/// Map tiles saved in the app's own storage, which the system doesn't clear
/// to free space the way it clears cache folders.
final mapCacheProvider = FutureProvider<MapCachingProvider>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return BuiltInMapCachingProvider.getOrCreateInstance(
    cacheDirectory: p.join(dir.path, 'map_tiles'),
    maxCacheSize: mapCacheBytes,
    overrideFreshAge: mapTileFreshFor,
  );
});
