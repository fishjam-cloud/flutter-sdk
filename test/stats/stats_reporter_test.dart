import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/stats/stats_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

RtcStats report(String id, String type, Map<String, Object?> values) =>
    RtcStats(id: id, type: type, timestampMs: 1000.5, values: values);

void main() {
  group('buildStatsReportJson (SPEC §17)', () {
    test('maps report ids to fields, keeping only RTP reports', () {
      final json = buildStatsReportJson([
        report('in-1', 'inbound-rtp', {'kind': 'video', 'packetsLost': 3}),
        report('out-1', 'outbound-rtp', {'kind': 'audio', 'bytesSent': 10}),
        report('src-1', 'media-source', {'kind': 'audio'}),
        report('cp-1', 'candidate-pair', {'state': 'succeeded'}),
      ]);

      expect(jsonDecode(json), {
        'in-1': {
          'id': 'in-1',
          'type': 'inbound-rtp',
          'timestamp': 1000.5,
          'kind': 'video',
          'packetsLost': 3,
        },
        'out-1': {
          'id': 'out-1',
          'type': 'outbound-rtp',
          'timestamp': 1000.5,
          'kind': 'audio',
          'bytesSent': 10,
        },
      });
    });

    test('is an empty object without RTP reports', () {
      expect(buildStatsReportJson(const []), '{}');
    });

    test('id and type come from the report, not from the values', () {
      final json = buildStatsReportJson([
        report('in-1', 'inbound-rtp', {'id': 'other', 'type': 'other'}),
      ]);
      expect(jsonDecode(json), {
        'in-1': {'id': 'in-1', 'type': 'inbound-rtp', 'timestamp': 1000.5},
      });
    });

    test('turns values JSON cannot represent into valid JSON', () {
      final json = buildStatsReportJson([
        report('in-1', 'inbound-rtp', {
          'nan': double.nan,
          'inf': double.infinity,
          'nested': {
            1: [double.nan, 2],
          },
          'object': const Duration(seconds: 1),
        }),
      ]);
      expect(jsonDecode(json), {
        'in-1': {
          'id': 'in-1',
          'type': 'inbound-rtp',
          'timestamp': 1000.5,
          'nan': null,
          'inf': null,
          'nested': {
            '1': [null, 2],
          },
          'object': '0:00:01.000000',
        },
      });
    });
  });

  group('StatsReporter', () {
    late List<String> sent;
    late List<String> logs;
    late int calls;
    late Future<List<RtcStats>> Function() getStats;
    late StatsReporter reporter;

    setUp(() {
      sent = [];
      logs = [];
      calls = 0;
      getStats = () async => [
        report('out-1', 'outbound-rtp', {'kind': 'video'}),
      ];
      reporter = StatsReporter(
        getStats: () {
          calls++;
          return getStats();
        },
        send: sent.add,
        logger: FishjamLogger(
          enabled: true,
          sink: (level, message, {error, stackTrace}) => logs.add(message),
        ),
      );
    });

    test('sends a report every 10 s after start', () {
      fakeAsync((async) {
        reporter.start();
        async.elapse(const Duration(seconds: 9));
        expect(sent, isEmpty);

        async.elapse(const Duration(seconds: 1));
        expect(sent, hasLength(1));
        expect(jsonDecode(sent.single), contains('out-1'));

        async.elapse(const Duration(seconds: 20));
        expect(sent, hasLength(3));
      });
    });

    test('start is idempotent', () {
      fakeAsync((async) {
        reporter
          ..start()
          ..start();
        async.elapse(const Duration(seconds: 10));
        expect(calls, 1);
      });
    });

    test('stop cancels further reports', () {
      fakeAsync((async) {
        reporter.start();
        async.elapse(const Duration(seconds: 10));
        reporter.stop();
        async.elapse(const Duration(minutes: 1));
        expect(sent, hasLength(1));
        expect(calls, 1);
      });
    });

    test('a report in flight when stopped is not sent', () {
      fakeAsync((async) {
        final pending = Completer<List<RtcStats>>();
        getStats = () => pending.future;
        reporter.start();
        async.elapse(const Duration(seconds: 10));
        reporter.stop();
        pending.complete(const []);
        async.flushMicrotasks();
        expect(sent, isEmpty);
      });
    });

    test('can be restarted after stop (new session)', () {
      fakeAsync((async) {
        final pending = Completer<List<RtcStats>>();
        getStats = () => pending.future;
        reporter.start();
        async.elapse(const Duration(seconds: 10));
        reporter
          ..stop()
          ..start();
        pending.complete(const []);
        async.flushMicrotasks();
        expect(sent, isEmpty, reason: 'the old session report is discarded');

        getStats = () async => const [];
        async.elapse(const Duration(seconds: 10));
        expect(sent, ['{}']);
      });
    });

    test('a failing getStats skips the tick and is logged', () {
      fakeAsync((async) {
        getStats = () async => throw StateError('closed');
        reporter.start();
        async.elapse(const Duration(seconds: 10));
        expect(sent, isEmpty);
        expect(logs.where((l) => l.contains('statistics')), isNotEmpty);

        getStats = () async => const [];
        async.elapse(const Duration(seconds: 10));
        expect(sent, ['{}']);
      });
    });

    test('stop before start is harmless', () {
      fakeAsync((async) {
        reporter.stop();
        async.elapse(const Duration(seconds: 30));
        expect(calls, 0);
      });
    });
  });
}
