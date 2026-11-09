import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/mesh_links.dart';
import '../l10n/l10n.dart';

/// Shows a link as a QR code with a copy button, so another phone can scan
/// it or the text can be pasted into a message.
Future<void> showLinkSheet(
  BuildContext context, {
  required String title,
  required MeshLink link,
  String? warning,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          // QR codes need a light background and dark modules to scan
          // reliably, whatever the app theme.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: link.url,
              size: 240,
              backgroundColor: Colors.white,
              semanticsLabel: 'QR code for $title',
            ),
          ),
          if (warning != null) ...[
            const SizedBox(height: 16),
            Text(warning, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          SelectableText(
            link.url,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(context.l10n.copyLink),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: link.url));
              messenger.showSnackBar(SnackBar(content: Text('Link copied')));
            },
          ),
        ],
      ),
    ),
  ),
);

/// Whether this device can scan QR codes with a camera.
bool get canScanQr => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

/// Opens the camera and returns the first MeshCore link it sees, or null if
/// the person backs out.
Future<MeshLink?> scanMeshLink(BuildContext context) => Navigator.of(context)
    .push<MeshLink>(MaterialPageRoute(builder: (_) => const QrScanScreen()));

/// Full-screen camera that looks for a MeshCore link. Other QR codes are
/// ignored with a hint.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.scanner});

  /// Replaces the camera view, for tests.
  final Widget Function(void Function(String text) onText)? scanner;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;
  String? _hint;

  void _onText(String text) {
    if (_done || !mounted) return;
    final link = MeshLink.parse(text);
    if (link == null) {
      setState(() => _hint = 'That QR code isn’t a MeshCore link.');
      return;
    }
    _done = true;
    Navigator.of(context).pop(link);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.scanAQRCode)),
    body: Stack(
      children: [
        Positioned.fill(
          child:
              widget.scanner?.call(_onText) ??
              MobileScanner(
                onDetect: (capture) {
                  for (final code in capture.barcodes) {
                    if (code.rawValue case final text?) _onText(text);
                  }
                },
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                          ? 'Allow camera access for NOTORYX Independent in '
                                'your device settings to scan QR codes.'
                          : 'The camera couldn’t start.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _hint ?? 'Point the camera at a MeshCore contact or channel QR code.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
