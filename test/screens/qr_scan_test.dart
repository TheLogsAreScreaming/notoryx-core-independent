import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/mesh_links.dart';
import 'package:notoryx_core/screens/qr_widgets.dart';

void main() {
  late void Function(String text) scan;

  Future<MeshLink?> openScanner(WidgetTester tester) async {
    MeshLink? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<MeshLink>(
                MaterialPageRoute(
                  builder: (_) => QrScanScreen(
                    scanner: (onText) {
                      scan = onText;
                      return const ColoredBox(color: Colors.black);
                    },
                  ),
                ),
              );
            },
            child: const Text('scan'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a MeshCore link closes the scanner with that link', (
    tester,
  ) async {
    MeshLink? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              got = await Navigator.of(context).push<MeshLink>(
                MaterialPageRoute(
                  builder: (_) => QrScanScreen(
                    scanner: (onText) {
                      scan = onText;
                      return const SizedBox();
                    },
                  ),
                ),
              );
            },
            child: const Text('scan'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    scan(
      'meshcore://channel/add?name=Public&secret=8b3387e9c5cdea6ac9e5edbaa115cd72',
    );
    await tester.pumpAndSettle();
    expect((got! as ChannelLink).name, 'Public');
  });

  testWidgets('other QR codes show a hint and keep scanning', (tester) async {
    await openScanner(tester);
    scan('https://example.com');
    await tester.pump();
    expect(find.text('That QR code isn’t a MeshCore link.'), findsOneWidget);
    expect(find.text('Scan a QR code'), findsOneWidget, reason: 'still open');
  });

  testWidgets('the share sheet shows a QR code and the link', (tester) async {
    final link = ChannelLink(name: '#trail', secret: List.filled(16, 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showLinkSheet(context, title: '#trail', link: link),
            child: const Text('share'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('QR code for #trail'), findsOneWidget);
    expect(find.text(link.url), findsOneWidget);
  });
}
