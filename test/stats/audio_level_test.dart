import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/stats/audio_level.dart';
import 'package:flutter_test/flutter_test.dart';

RtcStats report(String type, Map<String, Object?> values, {String? id}) =>
    RtcStats(id: id ?? type, type: type, timestampMs: 1, values: values);

void main() {
  test('reads audioLevel of the audio media-source report', () {
    expect(
      audioLevelFromStats([
        report('outbound-rtp', {'kind': 'audio'}),
        report('media-source', {'kind': 'audio', 'audioLevel': 0.42}),
      ]),
      0.42,
    );
  });

  test('accepts integer levels', () {
    expect(
      audioLevelFromStats([
        report('media-source', {'kind': 'audio', 'audioLevel': 1}),
      ]),
      1.0,
    );
  });

  test('uses the first audio media-source report', () {
    expect(
      audioLevelFromStats([
        report('media-source', {'kind': 'video', 'audioLevel': 0.9}),
        report('media-source', {'kind': 'audio', 'audioLevel': 0.1}, id: 'a'),
        report('media-source', {'kind': 'audio', 'audioLevel': 0.2}, id: 'b'),
      ]),
      0.1,
    );
  });

  test('is null without an audio media-source report', () {
    expect(
      audioLevelFromStats([
        report('media-source', {'kind': 'video', 'videoWidth': 1280}),
      ]),
      isNull,
    );
    expect(audioLevelFromStats(const []), isNull);
  });

  test('is null when the report has no numeric audioLevel', () {
    expect(
      audioLevelFromStats([
        report('media-source', {'kind': 'audio'}),
      ]),
      isNull,
    );
    expect(
      audioLevelFromStats([
        report('media-source', {'kind': 'audio', 'audioLevel': 'loud'}),
      ]),
      isNull,
    );
  });
}
