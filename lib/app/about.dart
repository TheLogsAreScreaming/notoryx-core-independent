import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'radio_connector.dart';
import 'connection.dart';

/// Where the source lives.
const sourceUrl =
    'https://github.com/TheLogsAreScreaming/notoryx-core-independent';

/// Where builds are published, and where problems are reported.
const releasesUrl =
    'https://github.com/TheLogsAreScreaming/notoryx-core-independent-releases';

/// This app's name and version as the platform reports it.
typedef AppVersion = ({String name, String version, String build});

/// The installed app's version. Tests replace this.
final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return (name: info.appName, version: info.version, build: info.buildNumber);
});

/// The phone or computer this runs on, e.g. "android 14 (…)".
final platformDescriptionProvider = Provider<String>(
  (ref) => '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
);

/// Everything a problem report needs, as plain lines to paste in an issue.
String reportDetails({
  required AppVersion app,
  required String platform,
  RadioConnectionState? connection,
}) {
  final lines = [
    'App: ${app.name} ${app.version} (build ${app.build})',
    'Device: $platform',
  ];
  if (connection is Connected) {
    final device = connection.radio.device;
    lines
      ..add('Radio: ${device.manufacturer ?? 'unknown model'}')
      ..add(
        'Firmware: ${device.firmwareVersion ?? 'unknown'} '
        '(protocol ${device.firmwareVersionCode})',
      )
      ..add('Connected over: ${_transport(connection.target)}');
  } else {
    lines.add('Radio: not connected');
  }
  return lines.join('\n');
}

String _transport(RadioTarget target) => switch (target) {
  BleTarget() => 'Bluetooth',
  UsbTarget() => 'USB',
  TcpTarget() => 'Wi-Fi (TCP)',
};
