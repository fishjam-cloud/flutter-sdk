import 'package:fishjam_client/src/rtc/flutter_webrtc_adapter.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nativeDataChannelInit', () {
    test('lets the native stack pick the stream id', () {
      // flutter_webrtc sends `id: 0` by default, which the native side applies
      // to every channel, so two channels collide on SCTP stream 0.
      final reliable = nativeDataChannelInit(const DataChannelInit());
      final lossy = nativeDataChannelInit(
        const DataChannelInit(ordered: false, maxRetransmits: 0),
      );

      expect(reliable, isNot(contains('id')));
      expect(lossy, isNot(contains('id')));
    });

    test('maps a reliable channel', () {
      expect(nativeDataChannelInit(const DataChannelInit()), {
        'ordered': true,
        'negotiated': false,
        'protocol': 'sctp',
      });
    });

    test('keeps maxRetransmits 0 for a lossy channel', () {
      expect(
        nativeDataChannelInit(
          const DataChannelInit(ordered: false, maxRetransmits: 0),
        ),
        {
          'ordered': false,
          'negotiated': false,
          'protocol': 'sctp',
          'maxRetransmits': 0,
        },
      );
    });
  });
}
