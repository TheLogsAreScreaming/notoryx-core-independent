import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mesh_links.dart';

const _channel = EventChannel('notoryx/deeplink');

/// Incoming `meshcore://` deep links as parsed [MeshLink] objects.
///
/// Null values are emitted for URIs that parse to nothing, so listeners
/// should guard with `if (link != null)`.
final deepLinkProvider = StreamProvider<MeshLink?>(
  (ref) => _channel
      .receiveBroadcastStream()
      .handleError((_) {}, test: (e) => e is MissingPluginException)
      .map((event) {
        if (event is! String) return null;
        return MeshLink.parse(event);
      }),
);
