import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/quick_messages.dart';
import '../l10n/l10n.dart';

/// What the person picked in the quick message sheet.
typedef QuickPick = ({String text, bool edit});

/// Lists the quick messages. Tapping one sends it; the pencil puts it in
/// the box to change first. Null if nothing was picked.
Future<QuickPick?> showQuickMessagePicker(BuildContext context) =>
    showModalBottomSheet<QuickPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _Picker(),
    );

class _Picker extends ConsumerWidget {
  const _Picker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(quickMessagesProvider).value ?? const <String>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.quickMessages,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const QuickMessagesScreen(),
                        ),
                      );
                    },
                    child: Text(context.l10n.editList),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              ListTile(title: Text(context.l10n.noQuickMessagesTapEditList)),
            for (final text in items)
              ListTile(
                title: Text(text),
                onTap: () => Navigator.pop<QuickPick>(context, (
                  text: text,
                  edit: false,
                )),
                trailing: IconButton(
                  tooltip: context.l10n.changeBeforeSending,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.pop<QuickPick>(context, (
                    text: text,
                    edit: true,
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Add, change, reorder and remove quick messages.
class QuickMessagesScreen extends ConsumerWidget {
  const QuickMessagesScreen({super.key});

  Future<String?> _ask(BuildContext context, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial.isEmpty ? 'New quick message' : 'Change message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(quickMessagesProvider).value ?? const <String>[];
    final quick = ref.read(quickMessagesProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.quickMessages),
        actions: [
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: quick.reset,
                child: Text(context.l10n.resetToTheStartingList),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(context.l10n.add),
        onPressed: () async {
          final text = await _ask(context);
          if (text != null) await quick.add(text);
        },
      ),
      body: items.isEmpty
          ? Center(child: Text(context.l10n.noQuickMessagesYet))
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length,
              buildDefaultDragHandles: false,
              onReorderItem: quick.move,
              itemBuilder: (context, i) => ListTile(
                key: ValueKey(items[i]),
                title: Text(items[i]),
                onTap: () async {
                  final text = await _ask(context, initial: items[i]);
                  if (text != null) await quick.edit(i, text);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.l10n.remove2(items[i]),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => quick.remove(i),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_handle,
                          semanticLabel: context.l10n.move,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
