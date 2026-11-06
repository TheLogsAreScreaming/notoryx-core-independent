import 'dart:async';

import '../radio/radio.dart';

/// A way to reach a radio, as listed on the connect screen. Targets can be
/// saved with [toJson] and restored with [RadioTarget.fromJson] so the app
/// can reconnect to the last radio.
sealed class RadioTarget {
  const RadioTarget();

  String get label;

  Map<String, Object?> toJson();

  /// Restores a saved target, or null if [json] isn't one.
  static RadioTarget? fromJson(Map<String, Object?> json) {
    final label = json['label'];
    return switch (json['kind']) {
      'ble' when json['id'] is String && label is String => BleTarget(
        deviceId: json['id']! as String,
        label: label,
      ),
      'usb' when json['id'] is String && label is String => UsbTarget.saved(
        id: json['id']! as String,
        label: label,
      ),
      'tcp' when json['host'] is String && json['port'] is int => TcpTarget(
        host: json['host']! as String,
        port: json['port']! as int,
      ),
      _ => null,
    };
  }
}

final class BleTarget extends RadioTarget {
  const BleTarget({
    required this.deviceId,
    required this.label,
    this.rssi,
    this.isMeshCore = true,
  });

  final String deviceId;
  @override
  final String label;
  final int? rssi;
  final bool isMeshCore;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'ble',
    'id': deviceId,
    'label': label,
  };
}

final class UsbTarget extends RadioTarget {
  UsbTarget(UsbRadioPort this.port) : id = port.id, label = port.label;

  /// A USB device remembered from before; it's looked up again by [id] when
  /// connecting, since the port object doesn't survive a restart.
  const UsbTarget.saved({required this.id, required this.label}) : port = null;

  final String id;
  @override
  final String label;
  final UsbRadioPort? port;

  @override
  Map<String, Object?> toJson() => {'kind': 'usb', 'id': id, 'label': label};
}

final class TcpTarget extends RadioTarget {
  const TcpTarget({required this.host, this.port = 5000});

  final String host;
  final int port;

  @override
  String get label => '$host:$port';

  @override
  Map<String, Object?> toJson() => {'kind': 'tcp', 'host': host, 'port': port};
}

/// Finds radios and opens links to them. The app uses [DeviceRadioConnector];
/// tests swap in a fake.
abstract interface class RadioConnector {
  bool get supportsUsb;

  /// With [all], every Bluetooth device nearby, not just MeshCore radios.
  Stream<BleTarget> scanBluetooth({bool all = false});

  Future<List<UsbTarget>> listUsb();

  Future<RadioLink> open(RadioTarget target);
}

final class DeviceRadioConnector implements RadioConnector {
  const DeviceRadioConnector();

  @override
  bool get supportsUsb => UsbRadioPorts.isSupported;

  @override
  Stream<BleTarget> scanBluetooth({bool all = false}) =>
      BleRadioScanner.scan(all: all).map(
        (r) => BleTarget(
          deviceId: r.deviceId,
          label: r.name,
          rssi: r.rssi,
          isMeshCore: r.isMeshCore,
        ),
      );

  @override
  Future<List<UsbTarget>> listUsb() async => [
    for (final port in await UsbRadioPorts.list()) UsbTarget(port),
  ];

  @override
  Future<RadioLink> open(RadioTarget target) => switch (target) {
    BleTarget(:final deviceId) => _openBle(deviceId),
    UsbTarget(:final port?) => UsbRadioPorts.connect(port),
    UsbTarget(:final id) => _openSavedUsb(id),
    TcpTarget(:final host, :final port) => TcpRadioLink.connect(
      host,
      port: port,
    ),
  };

  /// Connects straight away when the system still knows the radio. After a
  /// restart it may not, so scan briefly for it and try once more.
  Future<RadioLink> _openBle(String deviceId) async {
    try {
      return await BleRadioLink.connect(deviceId);
    } on Object {
      await BleRadioScanner.scan(duration: const Duration(seconds: 8))
          .firstWhere((r) => r.deviceId == deviceId)
          .timeout(const Duration(seconds: 9));
      return BleRadioLink.connect(deviceId);
    }
  }

  Future<RadioLink> _openSavedUsb(String id) async {
    for (final port in await UsbRadioPorts.list()) {
      if (port.id == id) return UsbRadioPorts.connect(port);
    }
    throw const LinkClosedException('the USB radio is not plugged in');
  }
}
