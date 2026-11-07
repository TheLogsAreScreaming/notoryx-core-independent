import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../radio/radio.dart';
import 'area_preset.dart';

/// The live list. The app bundles a copy for first launch and offline use.
const areaPresetsUrl =
    'https://raw.githubusercontent.com/TheLogsAreScreaming/'
    'notoryx-core-independent-releases/main/regional_presets.json';

/// Settings keys in the store.
const _cacheSetting = 'area_presets_cache';
const _choiceSetting = 'area_preset_choice';
const _dismissedSetting = 'area_preset_dismissed';

/// "Automatic": the area around the radio's position.
const autoArea = 'auto';

/// Downloads the live list; null when offline or not found.
final areaPresetsFetchProvider = Provider<Future<String?> Function()>(
  (ref) => _download,
);

/// Reads the bundled copy.
final bundledAreaPresetsProvider = Provider<Future<String> Function()>(
  (ref) =>
      () => rootBundle.loadString('assets/regional_presets.json'),
);

Future<String?> _download() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(Uri.parse(areaPresetsUrl));
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }
    return await response.transform(utf8.decoder).join();
  } on Object catch (e) {
    debugPrint('Area presets not refreshed: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Every listed area: the saved copy (or the bundled one) at once, then the
/// live list when it arrives.
final areaPresetsProvider =
    AsyncNotifierProvider<AreaPresetsController, List<AreaPreset>>(
      AreaPresetsController.new,
    );

class AreaPresetsController extends AsyncNotifier<List<AreaPreset>> {
  @override
  Future<List<AreaPreset>> build() async {
    final store = ref.read(storeProvider);
    final cached = await store.setting(_cacheSetting);
    var areas = cached == null
        ? const <AreaPreset>[]
        : parseAreaPresets(cached);
    if (areas.isEmpty) {
      areas = parseAreaPresets(await ref.read(bundledAreaPresetsProvider)());
    }
    Future.microtask(refresh);
    return areas;
  }

  /// Fetches the live list; keeps the current one if that fails.
  Future<void> refresh() async {
    final body = await ref.read(areaPresetsFetchProvider)();
    if (body == null || !ref.mounted) return;
    final fresh = parseAreaPresets(body);
    if (fresh.isEmpty) return;
    await ref.read(storeProvider).saveSetting(_cacheSetting, body);
    if (ref.mounted) state = AsyncData(fresh);
  }
}

/// [autoArea] or the id of the area the person picked.
final areaChoiceProvider = AsyncNotifierProvider<AreaChoice, String>(
  AreaChoice.new,
);

class AreaChoice extends AsyncNotifier<String> {
  @override
  Future<String> build() async =>
      await ref.read(storeProvider).setting(_choiceSetting) ?? autoArea;

  Future<void> choose(String idOrAuto) async {
    await ref.read(storeProvider).saveSetting(_choiceSetting, idOrAuto);
    state = AsyncData(idOrAuto);
  }
}

/// The [AreaPreset.signature] the person said "Not now" to.
final dismissedAreaProvider = AsyncNotifierProvider<DismissedArea, String?>(
  DismissedArea.new,
);

class DismissedArea extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.read(storeProvider).setting(_dismissedSetting);

  Future<void> dismiss(AreaPreset area) async {
    await ref
        .read(storeProvider)
        .saveSetting(_dismissedSetting, area.signature);
    state = AsyncData(area.signature);
  }
}

/// The connected radio's position, when it has one.
final radioPositionProvider = Provider<({double lat, double lon})?>((ref) {
  final state = ref.watch(connectionProvider);
  if (state is! Connected) return null;
  final self = state.radio.self;
  final lat = self.latitude, lon = self.longitude;
  if (lat == null || lon == null) return null;
  return (lat: lat, lon: lon);
});

/// The area whose settings apply: the one picked, or the one around the
/// radio.
final activeAreaProvider = Provider<AreaPreset?>((ref) {
  final areas = ref.watch(areaPresetsProvider).value ?? const [];
  final choice = ref.watch(areaChoiceProvider).value ?? autoArea;
  if (choice != autoArea) {
    for (final a in areas) {
      if (a.id == choice) return a;
    }
    return null;
  }
  final at = ref.watch(radioPositionProvider);
  return at == null ? null : areaAt(areas, at.lat, at.lon);
});

/// The connected radio's LoRa settings.
final radioSettingsProvider = Provider<RadioSettings?>((ref) {
  final state = ref.watch(connectionProvider);
  if (state is! Connected) return null;
  final self = state.radio.self;
  return (
    frequencyMhz: self.frequencyMhz,
    bandwidthKhz: self.bandwidthKhz,
    spreadingFactor: self.spreadingFactor,
    codingRate: self.codingRate,
  );
});

/// An area whose settings the radio doesn't use, and what would change.
typedef AreaOffer = ({AreaPreset area, List<String> changes});

/// What to offer in the banner; null when there's nothing to offer.
final areaOfferProvider = Provider<AreaOffer?>((ref) {
  final area = ref.watch(activeAreaProvider);
  final radio = ref.watch(radioSettingsProvider);
  if (area == null || radio == null) return null;
  final dismissed = ref.watch(dismissedAreaProvider);
  if (!dismissed.hasValue || dismissed.value == area.signature) return null;
  final changes = area.changesFrom(radio);
  return changes.isEmpty ? null : (area: area, changes: changes);
});

/// Puts [area]'s settings on the connected radio. Transmit power and the
/// path hash size stay as they are.
Future<void> applyArea(WidgetRef ref, AreaPreset area) => ref
    .read(connectionProvider.notifier)
    .setRadioParams(
      SetRadioParams(
        frequencyMhz: area.frequencyMhz,
        bandwidthKhz: area.bandwidthKhz,
        spreadingFactor: area.spreadingFactor,
        codingRate: area.codingRate,
      ),
    );
