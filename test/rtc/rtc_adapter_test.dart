// Values are built with `new` on purpose so constructors run at test time.
// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IceServer value semantics', () {
    final a = IceServer(urls: ['turn:a'], username: 'u', credential: 'c');
    expect(a, IceServer(urls: ['turn:a'], username: 'u', credential: 'c'));
    expect(
      a.hashCode,
      IceServer(urls: ['turn:a'], username: 'u', credential: 'c').hashCode,
    );
    expect(
      a,
      isNot(IceServer(urls: ['turn:b'], username: 'u', credential: 'c')),
    );
    expect(a, isNot(IceServer(urls: ['turn:a', 'turn:b'])));
    expect(a.toString(), contains('turn:a'));
    expect(RtcConfiguration().iceServers, isEmpty);
  });

  test('SessionDescription value semantics', () {
    final a = SessionDescription(type: SdpType.offer, sdp: 'v=0');
    expect(a, SessionDescription(type: SdpType.offer, sdp: 'v=0'));
    expect(
      a.hashCode,
      SessionDescription(type: SdpType.offer, sdp: 'v=0').hashCode,
    );
    expect(a, isNot(SessionDescription(type: SdpType.answer, sdp: 'v=0')));
    expect(a.toString(), contains('offer'));
  });

  test('IceCandidate value semantics', () {
    final a = IceCandidate(candidate: 'c', sdpMid: '0', sdpMLineIndex: 0);
    expect(a, IceCandidate(candidate: 'c', sdpMid: '0', sdpMLineIndex: 0));
    expect(
      a.hashCode,
      IceCandidate(candidate: 'c', sdpMid: '0', sdpMLineIndex: 0).hashCode,
    );
    expect(a, isNot(IceCandidate(candidate: 'c', sdpMid: '1')));
    expect(a.toString(), contains('c'));
  });

  test('RtpEncoding copyWith and value semantics', () {
    final e = RtpEncoding(
      rid: 'l',
      maxBitrateBps: 10,
      scaleResolutionDownBy: 4,
    );
    expect(e.copyWith(active: false).active, isFalse);
    expect(e.copyWith(clearMaxBitrate: true).maxBitrateBps, isNull);
    expect(e.copyWith(maxBitrateBps: 20).maxBitrateBps, 20);
    expect(e.copyWith(rid: 'm', scaleResolutionDownBy: 2).rid, 'm');
    expect(e.copyWith(), e);
    expect(e.hashCode, e.copyWith().hashCode);
    expect(e.toString(), contains('rid: l'));
  });

  test('RtpSendParameters, TransceiverInit, DataChannelInit, RtcStats', () {
    final p = RtpSendParameters(encodings: [RtpEncoding()]);
    expect(p.copyWith().encodings, p.encodings);
    expect(p.copyWith(encodings: []).encodings, isEmpty);
    final init = TransceiverInit(direction: TransceiverDirection.recvonly);
    expect(init.sendEncodings, isEmpty);
    expect(init.streams, isEmpty);
    final dc = DataChannelInit(ordered: false, maxRetransmits: 0);
    expect(dc, DataChannelInit(ordered: false, maxRetransmits: 0));
    expect(
      dc.hashCode,
      DataChannelInit(ordered: false, maxRetransmits: 0).hashCode,
    );
    expect(dc, isNot(DataChannelInit()));
    expect(dc.toString(), contains('maxRetransmits: 0'));
    final stats = RtcStats(
      id: 'a',
      type: 'inbound-rtp',
      timestampMs: 1,
      values: {},
    );
    expect(stats.type, 'inbound-rtp');
  });
}
