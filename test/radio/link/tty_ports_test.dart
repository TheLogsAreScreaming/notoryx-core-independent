import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/link/usb_radio_ports.dart';

void main() {
  test('USB serial ports are offered; Bluetooth and debug ports are not', () {
    for (final name in [
      'cu.usbmodem14101',
      'cu.usbserial-0001',
      'cu.SLAB_USBtoUART',
      'cu.wchusbserial1420',
      'ttyACM0',
      'ttyUSB1',
    ]) {
      expect(isRadioTty(name), isTrue, reason: name);
    }
    for (final name in [
      'cu.Bluetooth-Incoming-Port',
      'cu.BLTH',
      'tty.usbmodem14101',
      'ttyS0',
      'null',
    ]) {
      expect(isRadioTty(name), isFalse, reason: name);
    }
  });

  test('labels drop the device prefix', () {
    expect(ttyLabel('cu.usbmodem14101'), 'USB serial (usbmodem14101)');
    expect(ttyLabel('ttyACM0'), 'USB serial (ttyACM0)');
  });

  test('stty sets the radio speed and raw mode, per platform', () {
    expect(sttyArgs('/dev/cu.usbmodem1', macOS: true).take(3), [
      '-f',
      '/dev/cu.usbmodem1',
      '115200',
    ]);
    final linux = sttyArgs('/dev/ttyACM0', macOS: false);
    expect(linux.first, '-F');
    expect(linux, containsAll(['raw', '-echo', 'clocal']));
  });
}
