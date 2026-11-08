/// Recording a walk from the phone's GPS, and exporting it as GPX.
///
/// This uses the phone's GPS only and sends nothing over the mesh.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/data.dart';
import 'connection.dart';

/// One GPS reading.
typedef TrackFix = ({double latitude, double longitude, double? altitude});

/// The phone's moving position, or an error when location isn't allowed.
/// Tests replace this.
final trackFixesProvider = Provider<Stream<TrackFix> Function()>(
  (ref) => () async* {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const TrackLocationException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const TrackLocationException();
    }
    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: trackMinMetres,
            // Keeps GPS running with the screen off.
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Recording your track',
              notificationText: 'NOTORYX Independent is logging your GPS.',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: trackMinMetres,
          );
    yield* Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => (
        latitude: p.latitude,
        longitude: p.longitude,
        altitude: p.altitude == 0 ? null : p.altitude,
      ),
    );
  },
);

/// Metres moved before another point is stored.
const trackMinMetres = 10;

/// Location is off or not allowed.
final class TrackLocationException implements Exception {
  const TrackLocationException();

  @override
  String toString() =>
      'Location is off or not allowed for NOTORYX Independent.';
}

/// The id of the track being recorded, or null.
final trackRecorderProvider = NotifierProvider<TrackRecorder, int?>(
  TrackRecorder.new,
);

class TrackRecorder extends Notifier<int?> {
  StreamSubscription<TrackFix>? _fixes;

  @override
  int? build() {
    ref.onDispose(() => unawaited(_fixes?.cancel()));
    return null;
  }

  /// Starts a new track named [name]. Any earlier unfinished track is ended.
  Future<void> start(String name) async {
    if (state != null) return;
    final store = ref.read(storeProvider);
    await store.endOpenTracks();
    final id = await store.startTrack(name);
    state = id;
    final failed = Completer<void>();
    _fixes = ref
        .read(trackFixesProvider)()
        .listen(
          (fix) {
            final saved = store.addTrackPoint(
              id,
              latitude: fix.latitude,
              longitude: fix.longitude,
              altitude: fix.altitude,
            );
            unawaited(
              saved.catchError((Object e) {
                ref.read(connectionLogProvider).add('track: $e');
              }),
            );
          },
          onError: (Object e) {
            if (!failed.isCompleted) failed.completeError(e);
          },
        );
    // A refused permission arrives straight away; report it to the caller.
    await Future.any([
      failed.future,
      Future<void>.delayed(const Duration(milliseconds: 300)),
    ]).catchError((Object e) async {
      await stop();
      await store.deleteTrack(id);
      throw e;
    });
  }

  /// Stops recording and closes the track.
  Future<void> stop() async {
    await _fixes?.cancel();
    _fixes = null;
    if (state == null) return;
    state = null;
    await ref.read(storeProvider).endOpenTracks();
  }
}

/// Saves a finished GPX file. Tests replace this.
final trackFileSaverProvider =
    Provider<Future<bool> Function(String name, Uint8List bytes)>(
      (ref) =>
          (name, bytes) async =>
              await FilePicker.saveFile(
                fileName: name,
                bytes: bytes,
                dialogTitle: 'Save track',
              ) !=
              null,
    );

/// Length of the line through [points], in metres.
double trackLengthMetres(List<TrackPoint> points) {
  const distance = Distance();
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += distance(
      LatLng(points[i - 1].latitude, points[i - 1].longitude),
      LatLng(points[i].latitude, points[i].longitude),
    );
  }
  return total;
}

/// [track] as a GPX 1.1 document.
@visibleForTesting
String gpxFor(Track track, List<TrackPoint> points) {
  const escape = HtmlEscape(HtmlEscapeMode.element);
  String time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="NOTORYX Independent" '
      'xmlns="http://www.topografix.com/GPX/1/1">',
    )
    ..writeln('  <trk>')
    ..writeln('    <name>${escape.convert(track.name)}</name>')
    ..writeln('    <trkseg>');
  for (final p in points) {
    out.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}">');
    if (p.altitude case final ele?) out.writeln('        <ele>$ele</ele>');
    out
      ..writeln('        <time>${time(p.at)}</time>')
      ..writeln('      </trkpt>');
  }
  out
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return out.toString();
}

/// Asks where to save [track], and returns whether it was saved.
Future<bool> exportTrack(WidgetRef ref, Track track) async {
  final points = await ref.read(storeProvider).watchTrackPoints(track.id).first;
  final safe = track.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  return ref.read(trackFileSaverProvider)(
    '$safe.gpx',
    Uint8List.fromList(utf8.encode(gpxFor(track, points))),
  );
}
