import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/backup.dart';
import '../data/backup_crypto.dart';
import 'about.dart';
import 'connection.dart';
import 'quick_messages.dart';
import 'safety.dart';

/// Saving and picking backup files. The app uses the system file dialogs;
/// tests swap in a fake.
abstract interface class BackupFiles {
  /// Asks where to save [bytes] as [name]. Returns false if cancelled.
  Future<bool> save(String name, Uint8List bytes);

  /// Asks for a file and reads it, or returns null if cancelled.
  Future<Uint8List?> pick();
}

final class SystemBackupFiles implements BackupFiles {
  const SystemBackupFiles();

  @override
  Future<bool> save(String name, Uint8List bytes) async =>
      await FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        dialogTitle: 'Save NOTORYX backup',
      ) !=
      null;

  @override
  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a backup');
    return file?.readAsBytes();
  }
}

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => const SystemBackupFiles(),
);

/// Where backups are put together before saving. Tests replace this.
final backupTempProvider = FutureProvider<Directory>(
  (ref) => getTemporaryDirectory(),
);

/// PBKDF2 rounds for new backups. Tests use fewer to run quickly.
final backupIterationsProvider = Provider<int>((ref) => backupIterations);

/// Shortest password accepted for a backup.
const minBackupPassword = 8;

/// A backup file's name for [day], e.g. NOTORYX-backup-2026-11-07.notoryx.
String backupFileName(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'NOTORYX-backup-${day.year}-${two(day.month)}-${two(day.day)}'
      '.notoryx';
}

/// A backup opened with its password, ready to restore.
typedef OpenedBackup = ({BackupInfo info, Uint8List sqlite});

final backupServiceProvider = Provider<BackupService>(BackupService.new);

class BackupService {
  BackupService(this._ref);

  final Ref _ref;

  /// Makes an encrypted backup of everything and asks where to save it.
  /// Returns false if the person cancelled the save.
  Future<bool> backUp(String password) async {
    final db = _ref.read(databaseProvider);
    final temp = await _ref.read(backupTempProvider.future);
    final app = await _ref.read(appVersionProvider.future);
    final payload = await backupPayload(
      db,
      temp: temp,
      appVersion: app.version,
    );
    final iterations = _ref.read(backupIterationsProvider);
    // Key stretching takes a few seconds on a phone: keep it off the UI.
    final sealed = await Isolate.run(
      () => sealBackup(payload, password, iterations: iterations),
    );
    return _ref
        .read(backupFilesProvider)
        .save(backupFileName(DateTime.now()), sealed);
  }

  /// Asks for a backup file. Null if cancelled.
  Future<Uint8List?> pick() => _ref.read(backupFilesProvider).pick();

  /// Opens a picked file with its password. Throws [BackupException].
  Future<OpenedBackup> open(Uint8List file, String password) async {
    final payload = await Isolate.run(() => openBackup(file, password));
    return readPayload(
      payload,
      currentSchema: _ref.read(databaseProvider).schemaVersion,
    );
  }

  /// Replaces everything on this device with [backup]. Only while no radio
  /// is connected, so nothing writes to the database meanwhile.
  Future<RestoreSummary> restore(OpenedBackup backup) async {
    if (_ref.read(connectionProvider) is! Disconnected) {
      throw const BackupException('Disconnect the radio first.');
    }
    final summary = await restoreDatabase(
      _ref.read(databaseProvider),
      backup.sqlite,
      temp: await _ref.read(backupTempProvider.future),
    );
    // These hold settings they read once.
    _ref
      ..invalidate(safetyProvider)
      ..invalidate(quickMessagesProvider);
    return summary;
  }
}
