import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/coverage_sharing.dart';
import '../l10n/l10n.dart';

/// The entry for coverage sharing, for the wardrive screen.
class CoverageShareTile extends ConsumerWidget {
  const CoverageShareTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(coverageSharingProvider).settings;
    return ListTile(
      leading: const Icon(Icons.public),
      title: Text(context.l10n.coverageShareTitle),
      subtitle: Text(
        s.enabled
            ? context.l10n.coverageShareOn(_privacyName(context, s.privacy))
            : context.l10n.coverageShareOff,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CoverageShareScreen()),
      ),
    );
  }
}

String _privacyName(BuildContext context, CoveragePrivacy p) => switch (p) {
  CoveragePrivacy.live => context.l10n.coveragePrivacyLive,
  CoveragePrivacy.delayed => context.l10n.coveragePrivacyDelayed,
  CoveragePrivacy.anonymous => context.l10n.coveragePrivacyAnonymous,
};

String _privacyDetail(BuildContext context, CoveragePrivacy p) => switch (p) {
  CoveragePrivacy.live => context.l10n.coveragePrivacyLiveDetail,
  CoveragePrivacy.delayed => context.l10n.coveragePrivacyDelayedDetail,
  CoveragePrivacy.anonymous => context.l10n.coveragePrivacyAnonymousDetail,
};

/// Asks before sharing starts, saying exactly what is sent. True if the
/// user agreed.
Future<bool> confirmCoverageSharing(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.coverageConsentTitle),
      content: SingleChildScrollView(
        child: Text(context.l10n.coverageConsentBody),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.coverageConsentAgree),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Sharing with the NOTORYX coverage map: off until the user agrees, then
/// privacy, Wi-Fi, hidden ends, a mapper name, erase and stop.
class CoverageShareScreen extends ConsumerStatefulWidget {
  const CoverageShareScreen({super.key});

  @override
  ConsumerState<CoverageShareScreen> createState() =>
      _CoverageShareScreenState();
}

class _CoverageShareScreenState extends ConsumerState<CoverageShareScreen> {
  final _mapper = TextEditingController();
  bool _mapperLoaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _mapper.dispose();
    super.dispose();
  }

  CoverageSharing get _sharing => ref.read(coverageSharingProvider.notifier);

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _start() async {
    if (!await confirmCoverageSharing(context)) return;
    await _sharing.agreeAndStart();
  }

  Future<void> _erase() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.coverageErase),
        content: Text(context.l10n.coverageEraseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.coverageErase),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final n = await _sharing.eraseMyUploads();
      _say(l10n.coverageErased(n));
    } on Object catch (e) {
      _say(l10n.coverageEraseFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.coverageStop),
        content: Text(context.l10n.coverageStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.coverageStop),
          ),
        ],
      ),
    );
    if (ok == true) await _sharing.stop();
  }

  Future<void> _openMap() async {
    final l10n = context.l10n;
    try {
      final ok = await launchUrl(
        Uri.parse(coverageMapUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _say(coverageMapUrl);
    } on Object {
      _say(l10n.coverageOpenFailed(coverageMapUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coverageSharingProvider);
    final s = state.settings;
    if (state.loaded && !_mapperLoaded) {
      _mapperLoaded = true;
      _mapper.text = s.mapper;
    }
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.coverageShareTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.coverageShareIntro),
          ),
          if (!s.enabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.public),
                label: Text(l10n.coverageShareStart),
                onPressed: state.loaded ? () => unawaited(_start()) : null,
              ),
            )
          else ...[
            ListTile(
              title: Text(l10n.coveragePrivacyTitle),
              subtitle: Text(_privacyDetail(context, s.privacy)),
            ),
            RadioGroup<CoveragePrivacy>(
              groupValue: s.privacy,
              onChanged: (p) {
                if (p != null) unawaited(_sharing.setPrivacy(p));
              },
              child: Column(
                children: [
                  for (final p in CoveragePrivacy.values)
                    RadioListTile<CoveragePrivacy>(
                      value: p,
                      title: Text(_privacyName(context, p)),
                      subtitle: Text(_privacyDetail(context, p)),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              title: Text(l10n.coverageWifiOnly),
              value: s.wifiOnly,
              onChanged: (v) => unawaited(_sharing.setWifiOnly(v)),
            ),
            SwitchListTile(
              title: Text(l10n.coverageHideEnds),
              subtitle: Text(l10n.coverageHideEndsDetail),
              value: s.hideEnds,
              onChanged: (v) => unawaited(_sharing.setHideEnds(v)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _mapper,
                maxLength: 32,
                enabled: s.privacy != CoveragePrivacy.anonymous,
                decoration: InputDecoration(
                  labelText: l10n.coverageMapperName,
                  helperText: l10n.coverageMapperNameHint,
                  helperMaxLines: 3,
                ),
                onSubmitted: (v) => unawaited(_sharing.setMapper(v)),
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  if (_mapper.text.trim() != s.mapper) {
                    unawaited(_sharing.setMapper(_mapper.text));
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l10n.coverageWaiting(state.waiting)),
              subtitle: Text(l10n.coverageRecordingHint),
              trailing: TextButton(
                onPressed: () => unawaited(_sharing.upload()),
                child: Text(l10n.coverageSendNow),
              ),
            ),
            if (state.lastError case final error?)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(l10n.coverageLastError(error)),
              ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l10n.coverageErase),
              enabled: !_busy,
              onTap: () => unawaited(_erase()),
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(l10n.coverageStop),
              onTap: () => unawaited(_stop()),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(l10n.coverageOpenMap),
            subtitle: const Text(coverageMapUrl),
            onTap: () => unawaited(_openMap()),
          ),
          if (!s.enabled)
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l10n.coverageErase),
              subtitle: Text(l10n.coverageEraseOffHint),
              enabled: !_busy,
              onTap: () => unawaited(_erase()),
            ),
        ],
      ),
    );
  }
}
