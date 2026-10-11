/// Minimal stand-ins for the Tracks module's [LocalTrackRegistry],
/// [LocalTrack] and [RemoteStore], so the Engine can be tested on its own.
///
/// They follow SPEC §10–§14 only as far as the engine-level fixtures need
/// (single-stream and per-layer limits, metadata, mids, remote track
/// lifecycle); everything else throws [UnimplementedError].
library;

import 'dart:async';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pbenum.dart'
    as shared;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/tracks/local_track.dart';
import 'package:fishjam_client/src/tracks/remote_track.dart';
import 'package:fishjam_client/src/wire.dart';

const Map<Variant, int> _caps = {
  Variant.low: 150,
  Variant.medium: 500,
  Variant.high: 1500,
};
const Map<Variant, double> _scales = {Variant.low: 4.0, Variant.medium: 2.0};

/// A `LocalTrackFactory`-compatible function with simplified SPEC §13
/// resolution.
LocalTrack fakeLocalTrackFactory({
  required String trackId,
  required RtcMediaTrack track,
  required RtcMediaStream? stream,
  required TrackMetadata? metadata,
  required SimulcastConfig simulcastConfig,
  required BandwidthLimit maxBandwidth,
}) => FakeLocalTrack(
  trackId: trackId,
  kind: track.kind,
  track: track,
  stream: stream,
  metadata: metadata,
  simulcastConfig: simulcastConfig,
  maxBandwidth: _resolve(track.kind, simulcastConfig, maxBandwidth),
);

BandwidthLimit _resolve(
  MediaKind kind,
  SimulcastConfig simulcast,
  BandwidthLimit limit,
) {
  switch ((kind, simulcast.enabled, limit)) {
    case (MediaKind.audio, _, SingleBandwidthLimit()):
      return limit;
    case (MediaKind.video, false, SingleBandwidthLimit(:final kbps)):
      return BandwidthLimit.single(kbps <= 0 || kbps > 1500 ? 1500 : kbps);
    case (
      MediaKind.video,
      true,
      SimulcastBandwidthLimit(:final kbpsPerVariant),
    ):
      return BandwidthLimit.simulcast({
        for (final v in Variant.values)
          v: switch (kbpsPerVariant[v]) {
            final k? when k > 0 && k <= _caps[v]! => k,
            _ => _caps[v]!,
          },
      });
    case (MediaKind.video, true, SingleBandwidthLimit(kbps: <= 0)):
      return const BandwidthLimit.simulcast(_caps);
    case (_, _, SimulcastBandwidthLimit()):
      throw ArgumentError('a non-simulcast track expects a single limit');
    case _:
      throw UnimplementedError('fake bandwidth resolution for $limit');
  }
}

/// A local track that adds itself as a send transceiver.
class FakeLocalTrack implements LocalTrack {
  /// Creates a track.
  FakeLocalTrack({
    required this.trackId,
    required this.kind,
    required RtcMediaTrack? track,
    this.stream,
    TrackMetadata? metadata,
    this.simulcastConfig = const SimulcastConfig.disabled(),
    this.maxBandwidth = BandwidthLimit.unlimited,
  }) : _track = track,
       _metadata = metadata;
  // The track and metadata are mutable behind accessors, as in LocalTrack.
  // ignore_for_file: prefer_initializing_formals

  @override
  final String trackId;

  @override
  final MediaKind kind;

  @override
  final RtcMediaStream? stream;

  @override
  final SimulcastConfig simulcastConfig;

  @override
  final BandwidthLimit maxBandwidth;

  RtcMediaTrack? _track;
  TrackMetadata? _metadata;

  /// When set, [replaceTrack] throws it.
  Error? failReplace;

  @override
  String? mid;

  @override
  TrackNegotiationStatus negotiationStatus = TrackNegotiationStatus.pending;

  @override
  bool pendingMetadataUpdate = false;

  @override
  RtcRtpTransceiver? transceiver;

  @override
  RtcMediaTrack? get track => _track;

  @override
  TrackMetadata? get metadata => _metadata;

  @override
  set metadata(TrackMetadata? value) => _metadata = value;

  @override
  LocalTrackContext toContext() => LocalTrackContext(
    trackId: trackId,
    kind: kind,
    rtcTrack: _track,
    rtcStream: stream,
    metadata: _metadata,
    simulcastConfig: simulcastConfig,
    maxBandwidth: maxBandwidth,
  );

  @override
  Future<void> addToConnection(RtcPeerConnection pc) async {
    final init = TransceiverInit(
      direction: TransceiverDirection.sendonly,
      sendEncodings: _encodings(),
      streams: [?stream],
    );
    final track = _track;
    transceiver = track == null
        ? await pc.addTransceiverOfKind(kind, init)
        : await pc.addTransceiverWithTrack(track, init);
  }

  List<RtpEncoding> _encodings() {
    if (kind == MediaKind.audio) return const [];
    return switch (maxBandwidth) {
      SingleBandwidthLimit(:final kbps) => [
        RtpEncoding(maxBitrateBps: kbps * 1024),
      ],
      SimulcastBandwidthLimit(:final kbpsPerVariant) => [
        for (final v in Variant.values)
          RtpEncoding(
            rid: v.rid,
            active: simulcastConfig.enabledVariants.contains(v),
            maxBitrateBps: kbpsPerVariant[v]! * 1024,
            scaleResolutionDownBy: _scales[v],
          ),
      ],
    };
  }

  @override
  Future<ReplaceAction> replaceTrack(RtcMediaTrack? newTrack) async {
    final failure = failReplace;
    if (failure != null) throw failure;
    final old = _track;
    await transceiver?.sender.replaceTrack(newTrack);
    _track = newTrack;
    if (old != null && newTrack == null) return ReplaceAction.mute;
    if (old == null && newTrack != null) return ReplaceAction.unmute;
    return ReplaceAction.replace;
  }

  @override
  Future<void> setBandwidth(BandwidthLimit resolved) =>
      throw UnimplementedError();

  @override
  Future<void> setEncodingBandwidth(Variant variant, int resolvedKbps) =>
      throw UnimplementedError();

  @override
  Future<void> setEncodingActive(Variant variant, {required bool active}) =>
      throw UnimplementedError();

  @override
  Future<double?> audioLevel() => throw UnimplementedError();
}

/// Registry of [LocalTrack]s with the SPEC §10.1 offer maps.
class FakeLocalTrackRegistry implements LocalTrackRegistry {
  final _tracks = <LocalTrack>[];
  int _ids = 0;

  /// When set, [midToTrackId] waits for it (to hold an offer mid-build).
  Future<void>? midGate;

  @override
  String peerId = '';

  @override
  Object? peerMetadata;

  @override
  Object? serverMetadata;

  /// `(trackId, media track id)` of every successful [replaceTrack].
  final List<(String, String?)> replaced = [];

  @override
  List<LocalTrack> get tracks => List.unmodifiable(_tracks);

  @override
  LocalTrack byId(String trackId) => _tracks.firstWhere(
    (t) => t.trackId == trackId,
    orElse: () => throw ArgumentError.value(trackId, 'trackId', 'unknown'),
  );

  @override
  String newTrackId() => '$peerId:track-${++_ids}';

  @override
  void register(LocalTrack track) => _tracks.add(track);

  @override
  LocalTrack unregister(String trackId) {
    final track = byId(trackId);
    _tracks.remove(track);
    return track;
  }

  @override
  bool isPublished(RtcMediaTrack mediaTrack) =>
      _tracks.any((t) => t.track?.id == mediaTrack.id);

  @override
  Map<String, String> trackIdToMetadataJson() => {
    for (final t in _tracks)
      t.trackId: encodeMetadataJson(t.metadata?.toJson()),
  };

  @override
  Map<String, peer.MediaEvent_TrackBitrates> trackIdToBitrates() => {
    for (final t in _tracks)
      t.trackId: peer.MediaEvent_TrackBitrates(
        trackId: t.trackId,
        variantBitrates: switch (t.maxBandwidth) {
          SingleBandwidthLimit(:final kbps) => [
            peer.MediaEvent_VariantBitrate(
              variant: shared.Variant.VARIANT_UNSPECIFIED,
              bitrate: kbps > 0
                  ? kbps * 1024
                  : t.kind == MediaKind.audio
                  ? 50000
                  : 1536000,
            ),
          ],
          SimulcastBandwidthLimit(:final kbpsPerVariant) => [
            for (final v in Variant.values)
              peer.MediaEvent_VariantBitrate(
                variant: variantToProto(v),
                bitrate: kbpsPerVariant[v]! * 1024,
              ),
          ],
        },
      ),
  };

  @override
  Future<Map<String, String>> midToTrackId(
    List<RtcRtpTransceiver> transceivers,
  ) async {
    await midGate;
    final result = <String, String>{};
    for (final t in transceivers) {
      final mid = t.mid;
      final media = t.sender.track;
      if (mid == null || media == null) continue;
      for (final track in _tracks) {
        if (track.track?.id == media.id) result[mid] = track.trackId;
      }
    }
    for (final track in _tracks) {
      final mid = track.mid;
      if (mid != null) result[mid] = track.trackId;
    }
    return result;
  }

  @override
  void applyAnswerMids(Map<String, String> midToTrackId) {
    for (final MapEntry(key: mid, value: trackId) in midToTrackId.entries) {
      for (final t in _tracks) {
        if (t.trackId == trackId) t.mid = mid;
      }
    }
  }

  @override
  Future<void> replaceTrack(String trackId, RtcMediaTrack? newTrack) async {
    await byId(trackId).replaceTrack(newTrack);
    replaced.add((trackId, newTrack?.id));
  }

  @override
  LocalPeer toLocalPeer() => LocalPeer(
    id: peerId,
    metadata: Metadata(peer: peerMetadata, server: serverMetadata),
    tracks: {for (final t in _tracks) t.trackId: t.toContext()},
  );
}

/// Remote state with the TrackAdded / TrackReady / TrackRemoved lifecycle;
/// records every call in [calls].
class FakeRemoteStore implements RemoteStore {
  /// Creates a store emitting through [emit].
  FakeRemoteStore({required this.emit, FishjamLogger? logger})
    : logger = logger ?? FishjamLogger.disabled();

  /// Emits client events.
  final void Function(FishjamEvent event) emit;

  /// Logger.
  final FishjamLogger logger;

  /// Method names called, in order.
  final List<String> calls = [];

  /// Methods that throw [StateError] when called.
  final Set<String> throwOn = {};

  final _peers = <String, Peer>{};
  final _tracks = <String, RemoteTrackContext>{};
  final _mids = <String, String>{};

  void _call(String name) {
    calls.add(name);
    if (throwOn.contains(name)) throw StateError('$name failed');
  }

  @override
  void loadConnected(
    server.MediaEvent_Connected connected,
    String localPeerId,
  ) {
    _call('loadConnected');
    for (final MapEntry(key: id, value: e)
        in connected.endpointIdToEndpoint.entries) {
      if (id == localPeerId) continue;
      _peers[id] = Peer(
        id: id,
        type: e.endpointType,
        metadata: Metadata.fromServerJson(decodeMetadataJson(e.metadataJson)),
      );
    }
  }

  @override
  List<Peer> get peers => _peers.values.toList();

  @override
  List<Component> get components => const [];

  @override
  Map<String, RemoteTrackContext> get tracks => Map.unmodifiable(_tracks);

  @override
  void endpointAdded(server.MediaEvent_EndpointAdded event) =>
      _call('endpointAdded');

  @override
  void endpointUpdated(server.MediaEvent_EndpointUpdated event) =>
      _call('endpointUpdated');

  @override
  void endpointRemoved(server.MediaEvent_EndpointRemoved event) =>
      _call('endpointRemoved');

  @override
  void tracksAdded(server.MediaEvent_TracksAdded event) {
    _call('tracksAdded');
    for (final MapEntry(key: id, value: t) in event.trackIdToTrack.entries) {
      final track = RemoteTrackContext(
        trackId: id,
        endpointId: event.endpointId,
        rawMetadata: decodeMetadataJson(t.metadataJson),
        simulcastConfig: simulcastConfigFromProto(t.simulcastConfig),
      );
      _tracks[id] = track;
      emit(TrackAdded(track));
    }
  }

  @override
  void tracksRemoved(server.MediaEvent_TracksRemoved event) {
    _call('tracksRemoved');
    for (final id in event.trackIds) {
      final track = _tracks.remove(id);
      if (track != null) emit(TrackRemoved(track));
    }
  }

  @override
  void trackUpdated(server.MediaEvent_TrackUpdated event) =>
      _call('trackUpdated');

  @override
  void variantSwitched(server.MediaEvent_TrackVariantSwitched event) =>
      _call('variantSwitched');

  @override
  void variantEnabled(server.MediaEvent_TrackVariantEnabled event) =>
      _call('variantEnabled');

  @override
  void variantDisabled(server.MediaEvent_TrackVariantDisabled event) =>
      _call('variantDisabled');

  @override
  void vadNotification(server.MediaEvent_VadNotification event) =>
      _call('vadNotification');

  @override
  void applyAnswerMids(Map<String, String> midToTrackId) {
    _call('applyAnswerMids');
    for (final MapEntry(key: mid, value: id) in midToTrackId.entries) {
      if (_tracks.containsKey(id)) _mids[mid] = id;
    }
  }

  @override
  void trackReady(RtcTrackEvent event) {
    _call('trackReady');
    final id = _mids[event.mid];
    final track = id == null ? null : _tracks[id];
    if (track == null) return;
    final ready = track.copyWith(
      kind: event.track.kind,
      rtcTrack: event.track,
      rtcStream: event.streams.firstOrNull,
    );
    _tracks[id!] = ready;
    emit(TrackReady(ready));
  }

  @override
  void setTargetEncoding(String trackId, Variant variant) =>
      throw UnimplementedError();
}
