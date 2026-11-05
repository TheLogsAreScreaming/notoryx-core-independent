import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../support/radio_frames.dart';

/// A Bluetooth stack with one MeshCore radio on it. Frames written to RX are
/// answered by [respond] as TX notifications.
class _FakeBle extends UniversalBlePlatform {
  _FakeBle({this.hasMeshCoreService = true});

  final bool hasMeshCoreService;
  List<List<int>> Function(Uint8List frame) respond = (_) => [];
  final writes = <Uint8List>[];
  final subscribed = <String>[];
  int? requestedMtu;
  bool disconnected = false;
  ScanFilter? lastScanFilter;

  void advertise(String id, String name, int rssi) =>
      updateScanResult(BleDevice(deviceId: id, name: name, rssi: rssi));

  void dropConnection(String id) => updateConnection(id, false);

  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    scheduleMicrotask(() => updateConnection(deviceId, true));
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnected = true;
    scheduleMicrotask(() => updateConnection(deviceId, false));
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors, {
    DiscoverServicesPlatformConfig? platformConfig,
  }) async => [
    if (hasMeshCoreService)
      BleService(MeshCoreBle.service, [
        BleCharacteristic(MeshCoreBle.rx, [CharacteristicProperty.write], []),
        BleCharacteristic(MeshCoreBle.tx, [CharacteristicProperty.notify], []),
      ])
    else
      BleService('180f', []),
  ];

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty bleInputProperty,
  ) async => subscribed.add(characteristic);

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    writes.add(value);
    for (final reply in respond(value)) {
      scheduleMicrotask(
        () => updateCharacteristicValue(
          deviceId,
          MeshCoreBle.tx,
          Uint8List.fromList(reply),
          null,
        ),
      );
    }
  }

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async =>
      requestedMtu = expectedMtu;

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async => lastScanFilter = scanFilter;

  @override
  Future<void> stopScan() async {}

  @override
  Future<bool> isScanning() async => false;

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async =>
      disconnected
      ? BleConnectionState.disconnected
      : BleConnectionState.connected;

  @override
  Future<AvailabilityState> getBluetoothAvailabilityState() async =>
      AvailabilityState.poweredOn;

  @override
  Future<bool> enableBluetooth() async => true;

  @override
  Future<bool> disableBluetooth() async => false;

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) => throw UnimplementedError();

  @override
  Future<Uint8List> readDescriptorValue(
    String deviceId,
    String service,
    String characteristic,
    String descriptor, {
    Duration? timeout,
  }) => throw UnimplementedError();

  @override
  Future<void> writeDescriptorValue(
    String deviceId,
    String service,
    String characteristic,
    String descriptor,
    Uint8List value,
  ) => throw UnimplementedError();

  @override
  Future<int> readRssi(String deviceId) async => -60;

  @override
  Future<void> requestConnectionPriority(
    String deviceId,
    BleConnectionPriority priority,
  ) async {}

  @override
  Future<bool> isPaired(String deviceId) async => false;

  @override
  Future<bool> pair(String deviceId) async => true;

  @override
  Future<void> unpair(String deviceId) async {}

  @override
  Future<List<BleDevice>> getSystemDevices(List<String>? withServices) async =>
      [];
}

const _id = 'aa:bb:cc:dd:ee:ff';

void main() {
  late _FakeBle ble;

  setUp(() {
    ble = _FakeBle();
    UniversalBle.setInstance(ble);
  });

  test('connects, raises the MTU and subscribes to TX', () async {
    final link = await BleRadioLink.connect(_id);
    expect(ble.requestedMtu, 512);
    expect(
      ble.subscribed.map(
        (c) => BleUuidParser.compareStrings(c, MeshCoreBle.tx),
      ),
      [isTrue],
    );
    await link.close();
    expect(ble.disconnected, isTrue);
    await link.done;
  });

  test(
    'a session runs over BLE: one write per command, one notify per reply',
    () async {
      ble.respond = (frame) => switch (frame[0]) {
        CommandCode.appStart => [selfInfoFrame(name: 'Pocket Radio')],
        _ => [],
      };
      final link = await BleRadioLink.connect(_id);
      final session = RadioSession(link);
      final self = await session.request<SelfInfo>(
        const AppStart(appName: 'x'),
      );

      expect(self.name, 'Pocket Radio');
      expect(ble.writes.single, const AppStart(appName: 'x').encode());
      await session.close();
    },
  );

  test('a radio dropping the connection closes the link and session', () async {
    final link = await BleRadioLink.connect(_id);
    final session = RadioSession(link);
    final pending = session.run(const SendSelfAdvert());
    await pumpEventQueue();

    ble.dropConnection(_id);
    await link.done;
    await expectLater(pending, throwsA(isA<RadioDisconnected>()));
    expect(session.isClosed, isTrue);
  });

  test(
    'a device without the MeshCore service is refused and disconnected',
    () async {
      ble = _FakeBle(hasMeshCoreService: false);
      UniversalBle.setInstance(ble);
      await expectLater(
        BleRadioLink.connect(_id),
        throwsA(isA<LinkClosedException>()),
      );
      expect(ble.disconnected, isTrue);
    },
  );

  test(
    'scanning filters on the MeshCore service and reports each radio once',
    () async {
      final found = <BleRadioCandidate>[];
      final sub = BleRadioScanner.scan(duration: const Duration(seconds: 1))
          .listen(found.add);
      await pumpEventQueue();

      ble.advertise(_id, 'MeshCore-Base', -70);
      ble.advertise(_id, 'MeshCore-Base', -65);
      ble.advertise('11:22:33:44:55:66', 'MeshCore-Car', -80);
      await pumpEventQueue();
      await sub.cancel();

      expect(ble.lastScanFilter?.withServices, [MeshCoreBle.service]);
      expect(ble.lastScanFilter?.withNamePrefix, ['MeshCore']);
      expect(found.map((r) => r.name), ['MeshCore-Base', 'MeshCore-Car']);
      expect(found.first.rssi, -70);
    },
  );

  test('show-all scans without a filter and marks non-radios', () async {
    final found = <BleRadioCandidate>[];
    final sub = BleRadioScanner.scan(
      duration: const Duration(seconds: 1),
      all: true,
    ).listen(found.add);
    await pumpEventQueue();
    ble.advertise('11:11:11:11:11:11', 'Headphones', -40);
    ble.advertise(_id, 'MeshCore-Base', -70);
    await pumpEventQueue();
    await sub.cancel();

    expect(ble.lastScanFilter, isNull);
    expect(found.map((r) => (r.name, r.isMeshCore)), [
      ('Headphones', false),
      ('MeshCore-Base', true),
    ]);
  });

  test('a MeshCore advert is recognised by service or by name', () {
    expect(isMeshCoreAdvert('Trail', [MeshCoreBle.service]), isTrue);
    expect(isMeshCoreAdvert('MeshCore-Base', const []), isTrue);
    expect(isMeshCoreAdvert('Headphones', const ['180f']), isFalse);
    expect(isMeshCoreAdvert(null, const []), isFalse);
  });
}
