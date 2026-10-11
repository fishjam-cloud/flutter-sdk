/// Fishjam client SDK for Flutter.
///
/// Start with `FishjamClient`. See SPEC.md in the repository for the
/// behavioral contract.
library;

export 'src/fishjam_client.dart' show FishjamClient;
export 'src/livestream_api.dart'
    show
        PublishLivestreamResult,
        ReceiveLivestreamResult,
        publishLivestream,
        receiveLivestream;
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
export 'src/rtc/rtc_adapter.dart'
    show MediaKind, PeerConnectionState, RtcAdapter, RtcStats;
export 'src/tracks/bandwidth.dart' show simulcastCapsKbps, singleStreamCapKbps;
export 'src/version.dart' show packageVersion;
