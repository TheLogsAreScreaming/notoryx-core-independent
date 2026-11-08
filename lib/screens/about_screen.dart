import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/about.dart';
import '../app/connection.dart';

/// The app's version, where it comes from, and the details to put in a
/// problem report.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _copy(BuildContext context, String text, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final app = ref.watch(appVersionProvider).value;
    final platform = ref.watch(platformDescriptionProvider);
    final connection = ref.watch(connectionProvider);
    final details = app == null
        ? null
        : reportDetails(app: app, platform: platform, connection: connection);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            app?.name ?? 'NOTORYX Independent',
            style: theme.textTheme.headlineSmall,
          ),
          Text(
            app == null
                ? 'Version …'
                : 'Version ${app.version} (build ${app.build})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'An independent MeshCore companion app, part of the NOTORYX '
            'family. Written from scratch and free software under the MIT '
            'licence.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text('Report a problem', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Open an issue on the releases page below and paste these '
            'details, so we know which build, device and radio it was.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (details != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: details == null
                  ? null
                  : () => _copy(context, details, 'Details copied'),
              icon: const Icon(Icons.copy),
              label: const Text('Copy details'),
            ),
          ),
          const SizedBox(height: 24),
          _Link(
            label: 'Downloads and problem reports',
            url: releasesUrl,
            onCopy: () => _copy(context, releasesUrl, 'Link copied'),
          ),
          _Link(
            label: 'Source code',
            url: sourceUrl,
            onCopy: () => _copy(context, sourceUrl, 'Link copied'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: app?.name ?? 'NOTORYX Independent',
              applicationVersion: app?.version,
            ),
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.url, required this.onCopy});

  final String label;
  final String url;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.link),
    title: Text(label),
    subtitle: SelectableText(url),
    trailing: IconButton(
      tooltip: 'Copy link: $label',
      icon: const Icon(Icons.copy),
      onPressed: onCopy,
    ),
  );
}
