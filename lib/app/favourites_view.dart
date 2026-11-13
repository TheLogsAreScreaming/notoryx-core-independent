/// Showing only favourite (trusted) contacts on the Contacts tab and map.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import 'connection.dart';

/// Setting key; '1' when on.
const favouritesOnlyKey = 'view.favouritesOnly';

/// Whether the Contacts tab and map show favourites only. Shared by every
/// radio, since it's how you want to look at the mesh, not a radio setting.
final favouritesOnlyProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(storeProvider)
      .watchSettingsWithPrefix(favouritesOnlyKey)
      .map((m) => m[''] == '1'),
);

Future<void> setFavouritesOnly(MeshStore store, bool on) =>
    store.saveSetting(favouritesOnlyKey, on ? '1' : '0');
