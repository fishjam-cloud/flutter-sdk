import 'package:fishjam_client/src/rtc/flutter_webrtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offers carry no legacy receive constraints', () {
    // flutter_webrtc defaults to OfferToReceiveAudio/Video: true, which makes
    // the platform add receive transceivers the server did not ask for.
    expect(nativeOfferConstraints, {
      'mandatory': <String, dynamic>{},
      'optional': <dynamic>[],
    });
  });
}
