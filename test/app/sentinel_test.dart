import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/sentinel.dart';
import 'package:notoryx_core/data/data.dart';

const _key = 'ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12';

typedef _Req = ({String method, Uri url, String? body});

void main() {
  late Map<String, String> prefs;
  late List<_Req> requests;
  late SentinelResponse Function(_Req) respond;
  late DateTime now;
  var refs = 0;

  SentinelResponse json(int status, Object body) =>
      (status: status, body: jsonEncode(body));
  Map<String, Object?> decisions(List<Object?> bans) => {
    'network': 'meshcore',
    'advisory': true,
    'bans': bans,
  };

  SentinelService make() => SentinelService(
    read: (n) async => prefs[n],
    write: (n, v) async => prefs[n] = v,
    baseUrl: 'https://relay.test',
    now: () => now,
    newRef: () => 'ref-${++refs}',
    transport: (method, url, body) async {
      final r = (method: method, url: url, body: body);
      requests.add(r);
      return respond(r);
    },
  );

  Message msg({
    required MessageKind kind,
    String thread = 'c:0',
    String? name,
    bool outgoing = false,
  }) => Message(
    id: 1,
    radioKey: 'r',
    kind: kind,
    thread: thread,
    outgoing: outgoing,
    body: 'buy now',
    senderName: name,
    sentAt: 0,
    storedAt: 0,
    status: MessageStatus.values.first,
    attempts: 0,
    textType: 0,
  );

  setUp(() {
    prefs = {};
    requests = [];
    refs = 0;
    now = DateTime.utc(2026, 11, 13, 12);
    respond = (_) => json(200, decisions(const []));
  });

  test('off by default and makes no requests', () async {
    final s = make();
    await s.start();
    await s.refresh(force: true);
    expect(s.enabled, isFalse);
    expect(requests, isEmpty);
    expect(
      await s.report(nodeId: _key, reason: SentinelReason.spam),
      isA<SentinelReportRejected>(),
    );
    expect(requests, isEmpty);
    s.dispose();
  });

  test('labels direct senders by key and channel senders by name', () async {
    respond = (_) => json(
      200,
      decisions([
        {'nodeId': _key.toUpperCase(), 'caseRef': 'SNT-1'},
        {'nodeId': 'name:Spammy', 'caseRef': 'SNT-2'},
        'junk',
      ]),
    );
    final s = make();
    await s.start();
    await s.setEnabled(true);
    await s.syncDecisions(force: true);
    expect(
      requests.first.url.toString(),
      'https://relay.test/v1/meshcore/decisions',
    );
    expect(s.flaggedCount, 2);
    expect(
      s
          .banForMessage(msg(kind: MessageKind.direct, thread: 'd:$_key'))
          ?.caseRef,
      'SNT-1',
    );
    expect(
      s.banForMessage(msg(kind: MessageKind.channel, name: 'Spammy'))?.caseRef,
      'SNT-2',
    );
    expect(
      s.banForMessage(
        msg(kind: MessageKind.channel, name: 'Spammy', outgoing: true),
      ),
      isNull,
    );
    final spam = msg(kind: MessageKind.channel, name: 'Spammy');
    expect(s.hides(spam), isFalse);
    await s.setHideFlagged(true);
    expect(s.hides(spam), isTrue);
    s.dispose();

    respond = (_) => throw Exception('offline');
    final again = make();
    await again.start();
    expect(again.banForKey(_key)?.caseRef, 'SNT-1');
    await again.setEnabled(false);
    expect(again.banForKey(_key), isNull);
    again.dispose();
  });

  test(
    'reports carry only chosen fields; offline ones queue in order',
    () async {
      var online = true;
      respond = (r) {
        if (!online) throw Exception('offline');
        if (r.url.path.endsWith('/reports')) {
          final ref = (jsonDecode(r.body!) as Map)['externalRef'];
          return json(201, {'caseRef': 'SNT-$ref'});
        }
        return json(200, decisions(const []));
      };
      final s = make();
      await s.start();
      await s.setEnabled(true);
      final sent = await s.report(
        nodeId: sentinelNameId(' Bob '),
        nodeName: 'Bob',
        reason: SentinelReason.impersonation,
        messageExcerpt: 'y' * 300,
      );
      expect(sent, isA<SentinelReportSent>());
      final body = jsonDecode(
        requests.lastWhere((r) => r.method == 'POST').body!,
      ) as Map;
      expect(body['nodeId'], 'name:Bob');
      expect(body['reason'], 'Impersonation');
      expect((body['messageExcerpt'] as String).length, 280);

      online = false;
      await s.report(nodeId: _key, reason: SentinelReason.spam);
      await s.report(nodeId: _key, reason: SentinelReason.other);
      expect(s.queuedCount, 2);
      s.dispose();

      online = true;
      requests.clear();
      final again = make();
      await again.start();
      expect(await again.flushQueue(), 2);
      expect(
        [
          for (final r in requests.where((r) => r.method == 'POST'))
            (jsonDecode(r.body!) as Map)['externalRef'],
        ],
        ['ref-2', 'ref-3'],
      );
      await again.setEnabled(false);
      again.dispose();
    },
  );

  test(
    'sent reports show whether moderators are still reviewing them',
    () async {
      var state = 'under_review';
      respond = (r) {
        if (r.method == 'POST' && r.url.path.endsWith('/reports')) {
          return json(201, {'caseRef': 'SNT-1001'});
        }
        if (r.url.path.endsWith('/reports/ref-1')) {
          return json(200, {'ref': 'ref-1', 'state': state});
        }
        if (r.url.path.contains('/reports/')) {
          return json(404, {'error': 'Report not found'});
        }
        return json(200, decisions(const []));
      };
      final s = make();
      await s.start();
      await s.setEnabled(true);
      await s.report(nodeId: _key, reason: SentinelReason.spam);
      expect(s.sentReports.single.state, SentinelReportState.underReview);
      expect(s.sentReports.single.externalRef, 'ref-1');

      state = 'closed';
      await s.checkReportStatus(force: true);
      expect(s.sentReports.single.state, SentinelReportState.closed);
      expect(requests.last.method, 'GET');
      expect(
        requests.last.url.toString(),
        'https://relay.test/v1/meshcore/reports/ref-1',
      );

      // Closed reports are not asked about again; the state survives a restart.
      requests.clear();
      await s.checkReportStatus(force: true);
      expect(requests, isEmpty);
      s.dispose();
      final again = make();
      await again.start();
      expect(again.sentReports.single.state, SentinelReportState.closed);
      again.dispose();
    },
  );

  test('reports saved by older versions load and are not looked up', () async {
    prefs[SentinelService.prefSent] = jsonEncode([
      {'caseRef': 'SNT-1000', 'nodeName': 'Old', 'at': '2026-11-13T10:00:00Z'},
    ]);
    final s = make();
    await s.start();
    await s.setEnabled(true);
    expect(s.sentReports.single.caseRef, 'SNT-1000');
    expect(s.sentReports.single.state, isNull);
    await s.checkReportStatus(force: true);
    expect(requests.where((r) => r.url.path.contains('/reports/')), isEmpty);
    s.dispose();
  });

  test('400 is dropped; 429 and 5xx are queued; appeals map codes', () async {
    var status = 400;
    respond = (r) => r.method == 'POST'
        ? json(status, {'error': 'Invalid report'})
        : json(200, decisions(const []));
    final s = make();
    await s.start();
    await s.setEnabled(true);
    Future<SentinelReportOutcome> go() =>
        s.report(nodeId: _key, reason: SentinelReason.spam);
    expect(await go(), isA<SentinelReportRejected>());
    status = 429;
    expect(await go(), isA<SentinelReportQueued>());
    status = 503;
    expect(await go(), isA<SentinelReportQueued>());
    expect(s.queuedCount, 2);
    for (final (code, want) in [
      (201, SentinelAppealOutcome.received),
      (404, SentinelAppealOutcome.unknownCase),
      (409, SentinelAppealOutcome.notAppealable),
      (429, SentinelAppealOutcome.tooMany),
      (500, SentinelAppealOutcome.failed),
    ]) {
      status = code;
      expect(await s.appeal(caseRef: 'snt-4', statement: 'mine'), want);
    }
    expect(
      jsonDecode(
        requests.lastWhere((r) => r.url.path.endsWith('/appeals')).body!,
      ),
      {'caseRef': 'SNT-4', 'statement': 'mine'},
    );
    await s.setEnabled(false);
    s.dispose();
  });
}
