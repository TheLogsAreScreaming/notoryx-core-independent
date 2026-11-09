import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../data/data.dart';
import 'conversation_screen.dart';
import '../l10n/l10n.dart';

/// Searches every chat stored on this device for the connected radio.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({required this.radioKey, super.key});

  final String radioKey;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Message> _results = const [];
  String _searched = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    // Wait for a pause in typing so each keystroke isn't a query.
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(text));
  }

  Future<void> _search(String text) async {
    final results = await ref
        .read(storeProvider)
        .searchMessages(widget.radioKey, text);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searched = text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final channels =
        ref.watch(channelsProvider(widget.radioKey)).value ?? const [];
    final contacts =
        ref.watch(contactsProvider(widget.radioKey)).value ?? const [];
    String titleFor(String thread) {
      final id = thread.substring(2);
      if (thread.startsWith('c:')) {
        final slot = int.parse(id);
        return channels.where((c) => c.slot == slot).firstOrNull?.name ??
            'Channel $slot';
      }
      return contacts.where((c) => c.publicKey == id).firstOrNull?.name ??
          'Unknown ${id.substring(0, 6)}';
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.l10n.searchMessages,
            border: InputBorder.none,
          ),
          onChanged: _changed,
          onSubmitted: _search,
        ),
      ),
      body: _searched.isEmpty
          ? Center(child: Text(context.l10n.typeToSearchYourChats))
          : _results.isEmpty
          ? Center(child: Text('Nothing found for “$_searched”.'))
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final m = _results[i];
                final title = titleFor(m.thread);
                final when = DateTime.fromMillisecondsSinceEpoch(
                  m.sentAt * 1000,
                );
                return ListTile(
                  leading: Icon(
                    m.kind == MessageKind.channel
                        ? Icons.tag
                        : Icons.person_outline,
                  ),
                  title: Text(title),
                  subtitle: _Highlighted(
                    text: [
                      if (m.outgoing) 'You' else ?m.senderName,
                      m.body,
                    ].join(': '),
                    query: _searched,
                  ),
                  trailing: Text(
                    MaterialLocalizations.of(context).formatShortDate(when),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConversationScreen(
                        thread: m.thread,
                        title: title,
                        isChannel: m.kind == MessageKind.channel,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// [text] with each case-insensitive match of [query] in bold.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final needle = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (needle.isNotEmpty) {
      final at = lower.indexOf(needle, start);
      if (at < 0) break;
      spans
        ..add(TextSpan(text: text.substring(start, at)))
        ..add(
          TextSpan(
            text: text.substring(at, at + needle.length),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      start = at + needle.length;
    }
    spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
