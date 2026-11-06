import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/radio_connector.dart';

void main() {
  test('targets round-trip through JSON', () {
    final ble = RadioTarget.fromJson(
      const BleTarget(deviceId: 'aa', label: 'MeshCore-Base').toJson(),
    ) as BleTarget;
    expect((ble.deviceId, ble.label), ('aa', 'MeshCore-Base'));

    final tcp = RadioTarget.fromJson(
      const TcpTarget(host: '10.0.0.5', port: 5001).toJson(),
    ) as TcpTarget;
    expect((tcp.host, tcp.port), ('10.0.0.5', 5001));

    final usb = RadioTarget.fromJson(
      const UsbTarget.saved(id: '/dev/bus/usb/001/002', label: 'RAK').toJson(),
    ) as UsbTarget;
    expect(
      (usb.id, usb.label, usb.port),
      ('/dev/bus/usb/001/002', 'RAK', null),
    );
  });

  test('unreadable saved targets are ignored', () {
    expect(RadioTarget.fromJson(const {'kind': 'ble'}), isNull);
    expect(RadioTarget.fromJson(const {'kind': 'lora', 'id': 'x'}), isNull);
    expect(RadioTarget.fromJson(const {}), isNull);
  });
}
