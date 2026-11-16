/// Bringing message history over from a NOTORYX Core backup file.
///
/// NOTORYX Core's encrypted backup is JSON:
///
/// ```text
/// {"format": "bastion-meshcore-backup", "version": 1, "iterations": n,
///  "salt": b64 (32 bytes), "nonce": b64 (12), "ciphertext": b64,
///  "tag": b64 (16)}
/// ```
///
/// The key is PBKDF2-HMAC-SHA256 of the password, and the cipher AES-256-GCM
/// with the associated data `bastion-meshcore-backup-v1`. Inside is a JSON
/// map of Core's settings; its message history, when the backup has one,
/// is under `notoryx_history_v1` as
/// `{"direct"|"channel": {radio key: {conversation: [message JSON]}}}`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:pointycastle/export.dart';

import '../radio/radio.dart';
import 'mesh_store.dart' show Threads;
import 'tables.dart';

/// Why a Core backup couldn't be read.
enum CoreImportProblem { notCoreBackup, wrongPassword, noHistory }

final class CoreImportException implements Exception {
  const CoreImportException(this.problem);
  final CoreImportProblem problem;

  @override
  String toString() => 'CoreImportException(${problem.name})';
}

const _format = 'bastion-meshcore-backup';
const _associated = 'bastion-meshcore-backup-v1';
const _historyKey = 'notoryx_history_v1';

/// The settings map inside a Core backup [file]. Slow (key stretching), so
/// run it off the main isolate.
Map<String, Object?> openCoreBackup(List<int> file, String password) {
  final Object? envelope;
  try {
    envelope = jsonDecode(utf8.decode(file));
  } on FormatException {
    throw const CoreImportException(CoreImportProblem.notCoreBackup);
  }
  if (envelope is! Map ||
      envelope['format'] != _format ||
      envelope['version'] != 1) {
    throw const CoreImportException(CoreImportProblem.notCoreBackup);
  }
  final Uint8List salt, nonce, tag, body;
  final iterations = envelope['iterations'];
  try {
    salt = base64Decode(envelope['salt'] as String);
    nonce = base64Decode(envelope['nonce'] as String);
    tag = base64Decode(envelope['tag'] as String);
    body = base64Decode(envelope['ciphertext'] as String);
  } on Object {
    throw const CoreImportException(CoreImportProblem.notCoreBackup);
  }
  if (iterations is! int ||
      iterations < 1 ||
      iterations > 5000000 ||
      salt.length != 32 ||
      nonce.length != 12 ||
      tag.length != 16) {
    throw const CoreImportException(CoreImportProblem.notCoreBackup);
  }
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, 32));
  final key = kdf.process(Uint8List.fromList(utf8.encode(password)));
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(
        KeyParameter(key),
        128,
        nonce,
        Uint8List.fromList(utf8.encode(_associated)),
      ),
    );
  final Uint8List plain;
  try {
    plain = cipher.process(Uint8List.fromList([...body, ...tag]));
  } on InvalidCipherTextException {
    throw const CoreImportException(CoreImportProblem.wrongPassword);
  }
  final settings = jsonDecode(utf8.decode(plain));
  if (settings is! Map<String, dynamic>) {
    throw const CoreImportException(CoreImportProblem.notCoreBackup);
  }
  return settings;
}

/// One message from a Core backup, shaped for this app's database.
typedef CoreMessage = ({
  String radioKey,
  String thread,
  MessageKind kind,
  bool outgoing,
  String body,
  String? senderName,
  int sentAt,
  MessageStatus status,
  int? pathLength,
  int textType,
  String? authorPrefix,
  String? region,
  String dedupeKey,
});

/// The messages in a Core backup's [settings]. Throws
/// [CoreImportProblem.noHistory] when it was saved without chats.
List<CoreMessage> coreHistory(Map<String, Object?> settings) {
  final raw = settings[_historyKey];
  if (raw is! String) {
    throw const CoreImportException(CoreImportProblem.noHistory);
  }
  final Object? history;
  try {
    history = jsonDecode(raw);
  } on FormatException {
    throw const CoreImportException(CoreImportProblem.noHistory);
  }
  if (history is! Map) {
    throw const CoreImportException(CoreImportProblem.noHistory);
  }
  final out = <CoreMessage>[];
  for (final kind in MessageKind.values) {
    final radios = history[kind.name];
    if (radios is! Map) continue;
    for (final MapEntry(key: radio, value: chats) in radios.entries) {
      if (radio is! String || chats is! Map) continue;
      for (final MapEntry(key: chat, value: rows) in chats.entries) {
        if (chat is! String || rows is! List) continue;
        for (final row in rows) {
          final message = _message(kind, radio, chat, row);
          if (message != null) out.add(message);
        }
      }
    }
  }
  return out;
}

CoreMessage? _message(
  MessageKind kind,
  String radio,
  String chat,
  Object? row,
) {
  final Object? json;
  try {
    json = row is String ? jsonDecode(row) : row;
  } on FormatException {
    return null;
  }
  if (json is! Map) return null;
  final text = json['text'];
  final millis = json['timestamp'];
  if (text is! String || millis is! int) return null;
  final outgoing = json['isOutgoing'] == true;
  final direct = kind == MessageKind.direct;
  final slot = int.tryParse(chat);
  final thread = direct
      ? Threads.direct(chat.toLowerCase())
      : slot == null
      ? null
      : Threads.channel(slot);
  if (thread == null) return null;
  final statusIndex = json['status'];
  final status = !outgoing
      ? MessageStatus.received
      : switch ((direct, statusIndex)) {
          (true, 2) => MessageStatus.delivered,
          (true, 3) || (false, 2) => MessageStatus.failed,
          _ => MessageStatus.sent,
        };
  final room = json['fourByteRoomContactKey'];
  String? author;
  if (room is String && room.isNotEmpty) {
    try {
      final bytes = base64Decode(room);
      if (bytes.any((b) => b != 0)) author = toHex(bytes);
    } on FormatException {
      author = null;
    }
  }
  final id = json['messageId'];
  final identity = id is String && id.isNotEmpty
      ? id
      : hash.sha1.convert(utf8.encode('$millis|$outgoing|$text')).toString();
  final region = json['region'];
  final senderName = json['senderName'];
  final pathLength = json['pathLength'];
  return (
    radioKey: radio.toLowerCase(),
    thread: thread,
    kind: kind,
    outgoing: outgoing,
    body: smazUnwrap(text) ?? text,
    senderName: direct || senderName is! String ? null : senderName,
    sentAt: millis ~/ 1000,
    status: status,
    pathLength: pathLength is int ? pathLength : null,
    textType: json['isCli'] == true ? TextType.cliData.value : 0,
    authorPrefix: author,
    region: region is String ? region : null,
    dedupeKey: 'core:${radio.toLowerCase()}:$thread:$identity',
  );
}
