/// Area-limited messages (experimental): the setting, and whether the
/// connected radio can do it.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../radio/radio.dart';
import 'connection.dart';

export '../data/data.dart' show AreaSupport;

const areaMessagesSetting = 'area_messages';

/// Whether the option is on, and the radius of the circle around the radio.
class AreaMessages {
  const AreaMessages({
    this.on = false,
    this.radiusCode = defaultAreaRadiusCode,
  });

  final bool on;

  /// Index into [areaRadiusKm].
  final int radiusCode;

  double get radiusKm => areaRadiusKm[radiusCode];

  AreaMessages copyWith({bool? on, int? radiusCode}) => AreaMessages(
    on: on ?? this.on,
    radiusCode: radiusCode ?? this.radiusCode,
  );

  Map<String, Object?> toJson() => {'on': on, 'radius': radiusCode};

  static AreaMessages fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const AreaMessages();
    final radius = json['radius'];
    return AreaMessages(
      on: json['on'] == true,
      radiusCode: radius is int && radius >= 0 && radius < areaRadiusKm.length
          ? radius
          : defaultAreaRadiusCode,
    );
  }
}

final areaMessagesProvider =
    NotifierProvider<AreaMessagesNotifier, AreaMessages>(
      AreaMessagesNotifier.new,
    );

class AreaMessagesNotifier extends Notifier<AreaMessages> {
  @override
  AreaMessages build() {
    unawaited(_load());
    return const AreaMessages();
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(areaMessagesSetting);
    if (!ref.mounted || raw == null) return;
    try {
      state = AreaMessages.fromJson(jsonDecode(raw));
    } on FormatException {
      // Unreadable: keep it off.
    }
  }

  Future<void> _save() => ref
      .read(storeProvider)
      .saveSetting(areaMessagesSetting, jsonEncode(state.toJson()));

  Future<void> setOn(bool on) async {
    state = state.copyWith(on: on);
    await _save();
  }

  Future<void> setRadius(int code) async {
    state = state.copyWith(radiusCode: code.clamp(0, areaRadiusKm.length - 1));
    await _save();
  }
}

/// Whether the connected radio supports area limits; unknown with no radio.
/// Asked only while the option is on.
final areaSupportProvider = FutureProvider.autoDispose<AreaSupport>((
  ref,
) async {
  if (!ref.watch(areaMessagesProvider.select((s) => s.on))) {
    return AreaSupport.unknown;
  }
  final state = ref.watch(connectionProvider);
  if (state is! Connected) return AreaSupport.unknown;
  return state.sync.areaSupport();
});

/// The circle around the radio's advertised position, or null if the radio
/// has no position.
List<AreaCircle>? areaAround(SelfInfo self, int radiusCode) {
  final lat = self.latitude, lon = self.longitude;
  if (lat == null || lon == null || (lat == 0 && lon == 0)) return null;
  return [AreaCircle(latitude: lat, longitude: lon, radiusCode: radiusCode)];
}
