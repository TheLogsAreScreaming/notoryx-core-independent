import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/field_report.dart';
import '../app/position.dart';
import '../app/safety.dart';
import '../radio/radio.dart';

/// Fills in a report and sends it to your main chat and trip contacts.
class FieldReportScreen extends ConsumerStatefulWidget {
  const FieldReportScreen({required this.template, super.key});

  final ReportTemplate template;

  @override
  ConsumerState<FieldReportScreen> createState() => _FieldReportScreenState();
}

class _FieldReportScreenState extends ConsumerState<FieldReportScreen> {
  late final _fields = [
    for (final _ in widget.template.fields) TextEditingController(),
  ];
  bool _sending = false;

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final here = await ref.read(phonePositionProvider)();
    if (!mounted) return;
    if (here == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Your location isn’t available.')),
      );
      return;
    }
    final text =
        '${here.latitude.toStringAsFixed(5)},'
        '${here.longitude.toStringAsFixed(5)}';
    setState(() => _fields[widget.template.locationField].text = text);
  }

  Future<void> _send(List<String> messages) async {
    final messenger = ScaffoldMessenger.of(context);
    final safety = ref.read(safetyProvider.notifier);
    setState(() => _sending = true);
    try {
      var count = 0;
      for (final message in messages) {
        count = await safety.sendTripBrief(message);
      }
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.template.title} sent to $count.')),
      );
    } on SafetyException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on RadioRequestException {
      messenger.showSnackBar(
        const SnackBar(content: Text('The radio could not send it.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final theme = Theme.of(context);
    final messages = reportMessages(template, [
      for (final c in _fields) c.text,
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(template.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < template.fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _fields[i],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: template.fields[i].label,
                  hintText: template.fields[i].hint,
                  border: const OutlineInputBorder(),
                  suffixIcon: i == template.locationField
                      ? IconButton(
                          tooltip: 'Use my location',
                          icon: const Icon(Icons.my_location),
                          onPressed: _useLocation,
                        )
                      : null,
                ),
              ),
            ),
          if (messages == null)
            Text(
              'One field is too long for a message. Shorten it to send.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (messages.isNotEmpty) ...[
            Text(
              messages.length == 1
                  ? 'Will send'
                  : 'Will send as ${messages.length} messages',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final m in messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(m),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send to main chat and trip contacts'),
            onPressed: messages == null || messages.isEmpty || _sending
                ? null
                : () => _send(messages),
          ),
        ],
      ),
    );
  }
}
