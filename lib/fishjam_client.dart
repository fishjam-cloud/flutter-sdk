/// Fishjam client SDK for Flutter.
///
/// Start with `FishjamClient`. See SPEC.md in the repository for the
/// behavioral contract.
library;

export 'src/fishjam_client.dart' show FishjamClient;
export 'src/livestream/whep.dart'
    show ReceiveLivestreamResult, receiveLivestream;
export 'src/livestream/whip.dart'
    show PublishLivestreamResult, publishLivestream;
export 'src/models/config.dart';
export 'src/models/endpoint.dart' show Component, LocalPeer, Metadata, Peer;
export 'src/models/errors.dart'
    show
        AuthErrorReason,
        AuthException,
        ConnectionException,
        FishjamException,
        JoinErrorReason,
        JoinException,
        LivestreamError,
        LivestreamException,
        SessionEndReason,
        TrackTypeError;
export 'src/models/events.dart';
export 'src/models/simulcast.dart';
export 'src/models/track.dart';
export 'src/rtc/flutter_webrtc_adapter.dart'
    show
        FlutterWebrtcAdapter,
        FlutterWebrtcMediaStream,
        FlutterWebrtcMediaTrack;
export 'src/rtc/rtc_adapter.dart'
    show
        MediaKind,
        PeerConnectionState,
        RtcAdapter,
        RtcMediaStream,
        RtcMediaTrack,
        RtcStats;
export 'src/version.dart' show packageVersion;
