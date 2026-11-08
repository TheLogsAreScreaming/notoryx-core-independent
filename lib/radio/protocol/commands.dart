import 'dart:typed_data';

import 'bytes.dart';
import 'codes.dart';
import 'contact.dart';
import 'public_key.dart';

/// A frame the app sends to the radio. Each command knows its own layout, and
/// [encode] refuses to build a frame larger than the radio accepts.
sealed class RadioCommand {
  const RadioCommand();

  void _write(FrameWriter out);

  Uint8List encode() {
    final out = FrameWriter();
    _write(out);
    final frame = out.toBytes();
    if (frame.length > maxFrameSize) {
      throw ArgumentError(
        '$runtimeType: ${frame.length}-byte frame exceeds '
        'the $maxFrameSize-byte limit',
      );
    }
    return frame;
  }
}

/// Opens the session. The radio answers with its self info.
final class AppStart extends RadioCommand {
  const AppStart({this.appName = 'NOTORYX Core'});

  final String appName;

  @override
  void _write(FrameWriter out) {
    out.u8(CommandCode.appStart);
    out.bytes(Uint8List(7));
    out.string(appName);
  }
}

/// Asks for firmware details and tells the radio which protocol version the
/// app speaks.
final class DeviceQuery extends RadioCommand {
  const DeviceQuery({this.protocolVersion = appProtocolVersion});

  final int protocolVersion;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.deviceQuery)
      ..u8(protocolVersion);
  }
}

/// Streams the contact table: a start frame, one frame per contact, then an
/// end frame. With [since], only contacts changed after that radio time.
final class GetContacts extends RadioCommand {
  const GetContacts({this.since});

  final int? since;

  @override
  void _write(FrameWriter out) {
    out.u8(CommandCode.getContacts);
    if (since case final since?) out.u32(since);
  }
}

final class GetDeviceTime extends RadioCommand {
  const GetDeviceTime();

  @override
  void _write(FrameWriter out) => out.u8(CommandCode.getDeviceTime);
}

/// Sets the radio clock. The radio refuses to move its clock backwards.
final class SetDeviceTime extends RadioCommand {
  const SetDeviceTime(this.unixSeconds);

  final int unixSeconds;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.setDeviceTime)
      ..u32(unixSeconds);
  }
}

/// Broadcasts this node's advert, to neighbours only or flooded mesh-wide.
final class SendSelfAdvert extends RadioCommand {
  const SendSelfAdvert({this.flood = false});

  final bool flood;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.sendSelfAdvert)
      ..u8(flood ? 1 : 0);
  }
}

/// Renames this node. The radio keeps at most 31 bytes.
final class SetAdvertName extends RadioCommand {
  const SetAdvertName(this.name);

  final String name;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.setAdvertName)
      ..bytes(utf8Prefix(name, 31));
  }
}

final class SetAdvertPosition extends RadioCommand {
  const SetAdvertPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.setAdvertLatLon)
      ..i32(toMicrodegrees(latitude))
      ..i32(toMicrodegrees(longitude));
  }
}

/// Adds a contact, or updates it if the radio already has that key.
final class AddOrUpdateContact extends RadioCommand {
  const AddOrUpdateContact(this.contact);

  final RadioContact contact;

  @override
  void _write(FrameWriter out) {
    final path = Uint8List(maxPathSize)
      ..setRange(
        0,
        contact.outPath.length.clamp(0, maxPathSize),
        contact.outPath,
      );
    out
      ..u8(CommandCode.addUpdateContact)
      ..bytes(contact.publicKey.bytes)
      ..u8(contact.type.value)
      ..u8(contact.flags)
      ..u8(contact.outPathLength)
      ..bytes(path)
      ..fixedString(contact.name, 32)
      ..u32(contact.lastAdvert)
      ..i32(toMicrodegrees(contact.latitude))
      ..i32(toMicrodegrees(contact.longitude))
      ..u32(contact.lastModified);
  }
}

final class RemoveContact extends RadioCommand {
  const RemoveContact(this.publicKey);

  final PublicKey publicKey;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.removeContact)
      ..bytes(publicKey.bytes);
  }
}

/// Forgets the stored route to a contact so the next message floods.
final class ResetPath extends RadioCommand {
  const ResetPath(this.publicKey);

  final PublicKey publicKey;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.resetPath)
      ..bytes(publicKey.bytes);
  }
}

/// Takes the next queued message off the radio, or gets "no more messages".
final class SyncNextMessage extends RadioCommand {
  const SyncNextMessage();

  @override
  void _write(FrameWriter out) => out.u8(CommandCode.syncNextMessage);
}

/// Sends a direct message. The radio replies with a sent frame whose ack code
/// later comes back in a send-confirmed push when the recipient receives it.
final class SendTextMessage extends RadioCommand {
  const SendTextMessage({
    required this.recipient,
    required this.text,
    required this.timestamp,
    this.attempt = 0,
    this.type = TextType.plain,
  });

  final PublicKey recipient;
  final String text;

  /// Unix seconds. Resends of the same message keep the same timestamp.
  final int timestamp;

  /// 0 for the first try, counting up on resends.
  final int attempt;

  final TextType type;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.sendTextMessage)
      ..u8(type.value)
      ..u8(attempt)
      ..u32(timestamp)
      ..bytes(recipient.prefix())
      ..string(text);
  }
}

/// Sends text to a channel slot. The radio replies OK; channel messages have
/// no delivery ack.
final class SendChannelText extends RadioCommand {
  const SendChannelText({
    required this.channel,
    required this.text,
    required this.timestamp,
  });

  final int channel;
  final String text;
  final int timestamp;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.sendChannelText)
      ..u8(TextType.plain.value)
      ..u8(channel)
      ..u32(timestamp)
      ..string(text);
  }
}

final class GetChannel extends RadioCommand {
  const GetChannel(this.index);

  final int index;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.getChannel)
      ..u8(index);
  }
}

/// Writes a channel slot. An empty name with an all-zero secret clears it.
final class SetChannel extends RadioCommand {
  SetChannel({required this.index, required this.name, required this.secret}) {
    if (secret.length != 16) {
      throw ArgumentError.value(secret.length, 'secret', 'must be 16 bytes');
    }
  }

  final int index;
  final String name;
  final List<int> secret;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.setChannel)
      ..u8(index)
      ..fixedString(name, 32)
      ..bytes(secret);
  }
}

/// Changes the LoRa settings. The radio checks the ranges and answers OK or
/// an illegal-argument error.
final class SetRadioParams extends RadioCommand {
  const SetRadioParams({
    required this.frequencyMhz,
    required this.bandwidthKhz,
    required this.spreadingFactor,
    required this.codingRate,
    this.clientRepeat,
  });

  final double frequencyMhz;
  final double bandwidthKhz;
  final int spreadingFactor;

  /// 5 to 8, meaning 4/5 to 4/8.
  final int codingRate;

  /// Firmware v9+: whether this companion also repeats. Left out when null so
  /// older firmware sees the frame it expects.
  final bool? clientRepeat;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.setRadioParams)
      ..u32((frequencyMhz * 1000).round())
      ..u32((bandwidthKhz * 1000).round())
      ..u8(spreadingFactor)
      ..u8(codingRate);
    if (clientRepeat case final repeat?) out.u8(repeat ? 1 : 0);
  }
}

final class SetTxPower extends RadioCommand {
  const SetTxPower(this.dbm);

  final int dbm;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.setTxPower)
      ..i8(dbm);
  }
}

/// Asks for the radio's own receiver figures: noise floor, the last
/// packet's signal, and airtime so far. Answered with [RadioStats] on
/// firmware that has it.
final class GetRadioStats extends RadioCommand {
  const GetRadioStats();

  @override
  void _write(FrameWriter out) => out
    ..u8(CommandCode.getStats)
    ..u8(StatsGroup.radio);
}

final class GetBatteryAndStorage extends RadioCommand {
  const GetBatteryAndStorage();

  @override
  void _write(FrameWriter out) => out.u8(CommandCode.getBatteryAndStorage);
}

/// Runs a command on the radio's own command line (firmware 14 and later).
/// Answered with [CliReply].
final class RunCliCommand extends RadioCommand {
  const RunCliCommand(this.text);

  final String text;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.runCliCommand)
      ..string(text);
  }
}

/// Restarts the radio. It sends no reply.
final class Reboot extends RadioCommand {
  const Reboot();

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.reboot)
      ..string('reboot');
  }
}

/// Logs in to a repeater or room server. The result arrives later as a login
/// success or login fail push.
final class SendLogin extends RadioCommand {
  const SendLogin({required this.server, required this.password});

  final PublicKey server;
  final String password;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.sendLogin)
      ..bytes(server.bytes)
      ..string(password);
  }
}

/// Asks a repeater or room server for its status. The answer arrives later as
/// a status response push.
final class SendStatusRequest extends RadioCommand {
  const SendStatusRequest(this.server);

  final PublicKey server;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.sendStatusRequest)
      ..bytes(server.bytes);
  }
}

/// Asks a node for its sensor readings, or the connected radio itself when
/// [node] is null. A node answers later with a telemetry push; the radio
/// answers itself straight away with the same push and no other reply.
/// Repeaters and rooms only answer after a login (guest is enough).
final class SendTelemetryRequest extends RadioCommand {
  const SendTelemetryRequest([this.node]);

  final PublicKey? node;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.sendTelemetryRequest)
      ..bytes(const [0, 0, 0]);
    if (node case final key?) out.bytes(key.bytes);
  }
}

/// Asks whether the radio still holds a logged-in session with a server.
final class HasConnection extends RadioCommand {
  const HasConnection(this.server);

  final PublicKey server;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.hasConnection)
      ..bytes(server.bytes);
  }
}

final class Logout extends RadioCommand {
  const Logout(this.server);

  final PublicKey server;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.logout)
      ..bytes(server.bytes);
  }
}

/// Sets the radio's contact and advert preferences in one go. The firmware
/// reads every field, so send the current value of anything not changing.
final class SetOtherParams extends RadioCommand {
  const SetOtherParams({
    required this.manualAddContacts,
    required this.telemetryModes,
    required this.advertLocationPolicy,
    required this.multiAcks,
  });

  /// When true, new nodes are only added as allowed by [SetAutoAddConfig].
  final bool manualAddContacts;

  /// Two bits each: base, location and environment telemetry sharing.
  final ({int base, int location, int environment}) telemetryModes;

  /// 0 keeps position out of adverts, 1 shares it.
  final int advertLocationPolicy;

  /// Extra ack transmissions for direct messages.
  final int multiAcks;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.setOtherParams)
      ..u8(manualAddContacts ? 1 : 0)
      ..u8(
        (telemetryModes.base & 3) |
            ((telemetryModes.location & 3) << 2) |
            ((telemetryModes.environment & 3) << 4),
      )
      ..u8(advertLocationPolicy)
      ..u8(multiAcks);
  }
}

/// Which node types are still added automatically when manual add is on.
final class AutoAddConfig {
  const AutoAddConfig({required this.flags, required this.maxHops});

  static const replaceOldest = 0x01;
  static const companions = 0x02;
  static const repeaters = 0x04;
  static const roomServers = 0x08;
  static const sensors = 0x10;

  final int flags;

  /// 0 for no limit; otherwise only nodes fewer than this many hops away.
  final int maxHops;

  bool has(int flag) => flags & flag != 0;

  AutoAddConfig withFlag(int flag, bool on) =>
      AutoAddConfig(flags: on ? flags | flag : flags & ~flag, maxHops: maxHops);
}

final class GetAutoAddConfig extends RadioCommand {
  const GetAutoAddConfig();

  @override
  void _write(FrameWriter out) => out.u8(CommandCode.getAutoAddConfig);
}

final class SetAutoAddConfig extends RadioCommand {
  const SetAutoAddConfig(this.config);

  final AutoAddConfig config;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.setAutoAddConfig)
      ..u8(config.flags)
      ..u8(config.maxHops.clamp(0, 64));
  }
}

/// Sends a trace along [hops], a list of node hashes each [hashBytes] long
/// (1, 2 or 4). Each node on the list records how well it heard the trace
/// and passes it on; whoever hears the last one gets a trace data push
/// carrying [tag].
final class SendTracePath extends RadioCommand {
  SendTracePath({
    required this.tag,
    required this.hops,
    required this.hashBytes,
    this.authCode = 0,
  }) {
    if (!const [1, 2, 4].contains(hashBytes)) {
      throw ArgumentError.value(hashBytes, 'hashBytes', 'must be 1, 2 or 4');
    }
    if (hops.isEmpty || hops.any((h) => h.length != hashBytes)) {
      throw ArgumentError.value(hops, 'hops');
    }
  }

  final int tag;
  final int authCode;
  final List<List<int>> hops;
  final int hashBytes;

  @override
  void _write(FrameWriter out) {
    out
      ..u8(CommandCode.sendTracePath)
      ..u32(tag)
      ..u32(authCode)
      ..u8(switch (hashBytes) {
        1 => 0,
        2 => 1,
        _ => 2,
      });
    for (final hop in hops) {
      out.bytes(hop);
    }
  }
}
