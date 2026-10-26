/// Fishjam client SDK for Flutter. Start with `FishjamClient`.
library;

export 'src/audio_output/audio_output_manager.dart'
    show
        AndroidAudioOutput,
        AudioDevice,
        AudioDeviceType,
        AudioOutputChangedInfo,
        AudioOutputManager,
        IosAudioOutput,
        IosAudioOutputOverride;
export 'src/background/call_kit.dart'
    show
        CallEndedReason,
        CallKit,
        CallKitAction,
        CallKitConfig,
        CallKitEnded,
        CallKitFailed,
        CallKitHeld,
        CallKitMuted,
        CallKitStarted;
export 'src/background/foreground_service.dart'
    show
        ForegroundService,
        ForegroundServiceConfig,
        ForegroundServiceImportance;
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
        AudioOutputErrorCode,
        AudioOutputException,
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
export 'src/rtc/rtc_adapter.dart' show MediaKind, PeerConnectionState, RtcStats;
export 'src/signaling/auth.dart' show fishjamUrlFromId;
export 'src/tracks/bandwidth.dart' show simulcastCapsKbps, singleStreamCapKbps;
export 'src/version.dart' show packageVersion;
