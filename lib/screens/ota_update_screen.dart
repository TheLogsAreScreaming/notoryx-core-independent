import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nordic_dfu/nordic_dfu.dart';

import '../l10n/l10n.dart';

/// Minimum firmware protocol version that reliably supports BLE DFU.
/// Protocol 11 corresponds to firmware v1.15.0.
const _minDfuVersionCode = 11;

/// In-app firmware update for nRF52-based radios, using the Nordic DFU
/// protocol. Only reachable when the radio is connected over BLE and its
/// firmware reports a version code ≥ [_minDfuVersionCode].
class OtaUpdateScreen extends StatefulWidget {
  const OtaUpdateScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.firmwareVersionCode,
  });

  final String deviceId;
  final String deviceName;
  final int firmwareVersionCode;

  @override
  State<OtaUpdateScreen> createState() => _OtaUpdateScreenState();
}

enum _OtaState { idle, inProgress, done, error }

class _OtaUpdateScreenState extends State<OtaUpdateScreen> {
  _OtaState _state = _OtaState.idle;
  String? _filePath;
  String? _fileName;
  int _progress = 0;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
    });
  }

  Future<void> _confirmAndStart() async {
    if (_filePath == null) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.otaConfirmTitle),
        content: Text(l10n.otaConfirmBody(_fileName!)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.otaFlashIt),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _startDfu();
  }

  Future<void> _startDfu() async {
    setState(() {
      _state = _OtaState.inProgress;
      _progress = 0;
      _errorMessage = null;
    });

    try {
      await NordicDfu().startDfu(
        widget.deviceId,
        _filePath!,
        fileInAsset: false,
        forceDfu: false,
        progressListener: DefaultDfuProgressListenerAdapter(
          onProgressChangedHandle: (_, percent, __, ___, ____, _____) {
            if (mounted) setState(() => _progress = percent);
          },
          onDfuCompletedHandle: (_) {
            if (mounted) setState(() => _state = _OtaState.done);
          },
          onErrorHandle: (_, error, __, message) {
            if (mounted) {
              setState(() {
                _state = _OtaState.error;
                _errorMessage = message ?? 'Error $error';
              });
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _OtaState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tooOld = widget.firmwareVersionCode < _minDfuVersionCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.otaTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tooOld)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.otaOlderFirmware(_minDfuVersionCode),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),

            if (!tooOld) ...[
              Text(
                l10n.otaIntro(widget.deviceName),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (_state == _OtaState.idle ||
                  _state == _OtaState.done ||
                  _state == _OtaState.error) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    _fileName ?? l10n.otaPickFile,
                  ),
                  onPressed: _pickFile,
                ),
                const SizedBox(height: 16),
                if (_state == _OtaState.done)
                  _StatusCard(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    textColor:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                    text: l10n.otaDone,
                  ),
                if (_state == _OtaState.error && _errorMessage != null)
                  _StatusCard(
                    color: Theme.of(context).colorScheme.errorContainer,
                    textColor: Theme.of(context).colorScheme.onErrorContainer,
                    text: l10n.otaError(_errorMessage!),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.system_update_alt),
                  label: Text(l10n.otaStartFlash),
                  onPressed: _filePath != null ? _confirmAndStart : null,
                ),
              ],

              if (_state == _OtaState.inProgress) ...[
                Text(
                  l10n.otaProgress(_progress),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _progress / 100),
                const SizedBox(height: 8),
                Text(
                  l10n.otaKeepClose,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.color,
    required this.textColor,
    required this.text,
  });

  final Color color;
  final Color textColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: TextStyle(color: textColor)),
      ),
    );
  }
}
