import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:notoryx_core/app/node_look.dart';
import 'package:notoryx_core/data/backup.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('looks encode and decode', () {
    final colour = NodeLook.decode(
      const NodeColour(Color(0xFF1565C0)).encode(),
    );
    expect(colour, isA<NodeColour>());
    expect((colour! as NodeColour).colour.toARGB32(), 0xFF1565C0);

    final photo = NodeLook.decode(
      NodePhoto(Uint8List.fromList([1, 2, 3])).encode(),
    );
    expect((photo! as NodePhoto).jpeg, [1, 2, 3]);

    expect(NodeLook.decode('not json'), isNull);
    expect(NodeLook.decode('{"other":1}'), isNull);
    expect(NodeLook.decode('[1]'), isNull);
  });

  test('nodeInitials takes up to two letters', () {
    expect(nodeInitials('Alice Base Camp'), 'AB');
    expect(nodeInitials('bob'), 'B');
    expect(nodeInitials('🙂 Zed'), 'Z');
    expect(nodeInitials('  '), '');
    expect(nodeInitials('élan vital'), 'ÉV');
  });

  test('onColour picks the readable text colour', () {
    expect(onColour(const Color(0xFFF9A825)), const Color(0xFF000000));
    expect(onColour(const Color(0xFF1565C0)), const Color(0xFFFFFFFF));
  });

  test('squareAvatarJpeg crops to a small centred square', () {
    final wide = img.Image(width: 400, height: 200);
    final jpeg = squareAvatarJpeg(Uint8List.fromList(img.encodePng(wide)))!;
    final back = img.decodeJpg(jpeg)!;
    expect(back.width, nodePhotoSize);
    expect(back.height, nodePhotoSize);
    expect(squareAvatarJpeg(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('looks are saved, cleared and kept in backups', () async {
    final temp = await Directory.systemTemp.createTemp('look');
    addTearDown(() => temp.delete(recursive: true));
    final source = MeshDatabase.inMemory();
    final store = MeshStore(source);
    const key = 'ABCDEF0123';
    await saveNodeLook(store, key, const NodeColour(Color(0xFF2E7D32)));
    await saveNodeLook(store, 'gone', const NodeColour(Color(0xFF2E7D32)));
    await saveNodeLook(store, 'gone', null);
    expect(await store.setting(nodeLookKey('gone')), isNull);
    expect(await store.setting(nodeLookKey(key)), isNotNull);
    expect(nodeLookKey(key), 'nodeLook.abcdef0123');

    final payload = await backupPayload(source, temp: temp, appVersion: 'x');
    await source.close();
    final target = MeshDatabase.inMemory();
    addTearDown(target.close);
    final read = readPayload(payload, currentSchema: target.schemaVersion);
    await restoreDatabase(target, read.sqlite, temp: temp);
    final raw = await MeshStore(target).setting(nodeLookKey(key));
    expect(NodeLook.decode(raw!), isA<NodeColour>());
  });
}
