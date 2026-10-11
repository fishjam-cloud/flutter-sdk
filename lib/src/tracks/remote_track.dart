/// Remote endpoints and tracks (SPEC §14).
///
/// Owner: **Tracks** agent. The Engine forwards server media events here;
/// this module owns all remote state and emits the remote events.
library;

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
import 'package:fishjam_client/src/wire.dart';

/// Remote endpoints and tracks of a session.
///
/// Every method logs and ignores unknown endpoint or track ids (SPEC §7);
/// events about the local endpoint are ignored without any state change.
class RemoteStore {
  /// Creates an empty store.
  RemoteStore({
    required this._logger,
    required this._emit,
    required this._sendMediaEvent,
  });

  final FishjamLogger _logger;
  final void Function(FishjamEvent event) _emit;
  final void Function(peer.MediaEvent event) _sendMediaEvent;

  final Map<String, _Endpoint> _endpoints = {};
  final Map<String, _RemoteTrack> _tracks = {};
  String _localPeerId = '';

  /// Loads the snapshot from `connected`, skipping [localPeerId]. Emits
  /// nothing (SPEC §14.1). Replaces any previous state.
  void loadConnected(
    server.MediaEvent_Connected connected,
    String localPeerId,
  ) {
    _endpoints.clear();
    _tracks.clear();
    _localPeerId = localPeerId;
    for (final MapEntry(key: id, value: endpoint)
        in connected.endpointIdToEndpoint.entries) {
      if (id == localPeerId) continue;
      final type = endpoint.endpointType;
      final isComponent = componentEndpointTypes.contains(type);
      if (!isComponent && !peerEndpointTypes.contains(type)) {
        _logger.debug('Ignoring endpoint $id of unknown type "$type"');
        continue;
      }
      final stored = _Endpoint(
        id: id,
        type: type,
        isComponent: isComponent,
        metadata: _endpointMetadata(endpoint.metadataJson),
      );
      _endpoints[id] = stored;
      for (final MapEntry(key: trackId, value: track)
          in endpoint.trackIdToTrack.entries) {
        _addTrack(stored, trackId, track);
      }
    }
  }

  /// Current peers.
  List<Peer> get peers => [
    for (final e in _endpoints.values)
      if (!e.isComponent) _peerOf(e),
  ];

  /// Current components.
  List<Component> get components => [
    for (final e in _endpoints.values)
      if (e.isComponent) _componentOf(e),
  ];

  /// Current remote tracks by id.
  Map<String, RemoteTrackContext> get tracks => Map.unmodifiable({
    for (final t in _tracks.values) t.trackId: t.toContext(),
  });

  /// `endpointAdded`: always a peer of type `exwebrtc` → `PeerJoined`.
  void endpointAdded(server.MediaEvent_EndpointAdded event) {
    final id = event.endpointId;
    if (id == _localPeerId) return;
    if (_endpoints.containsKey(id)) {
      _logger.warn('endpointAdded for already known endpoint $id; ignored');
      return;
    }
    final endpoint = _Endpoint(
      id: id,
      type: 'exwebrtc',
      isComponent: false,
      metadata: _endpointMetadata(event.metadataJson),
    );
    _endpoints[id] = endpoint;
    _emit(PeerJoined(_peerOf(endpoint)));
  }

  /// `endpointUpdated` → `PeerUpdated` / `ComponentUpdated`.
  void endpointUpdated(server.MediaEvent_EndpointUpdated event) {
    final endpoint = _knownEndpoint(event.endpointId, 'endpointUpdated');
    if (endpoint == null) return;
    endpoint.metadata = _endpointMetadata(event.metadataJson);
    _emit(
      endpoint.isComponent
          ? ComponentUpdated(_componentOf(endpoint))
          : PeerUpdated(_peerOf(endpoint)),
    );
  }

  /// `endpointRemoved` for another endpoint: `TrackRemoved` per track, then
  /// `PeerLeft` / `ComponentRemoved`.
  void endpointRemoved(server.MediaEvent_EndpointRemoved event) {
    final endpoint = _knownEndpoint(event.endpointId, 'endpointRemoved');
    if (endpoint == null) return;
    final before = endpoint.isComponent
        ? ComponentRemoved(_componentOf(endpoint))
        : PeerLeft(_peerOf(endpoint));
    for (final trackId in [...endpoint.trackIds]) {
      _removeTrack(endpoint, trackId);
    }
    _endpoints.remove(endpoint.id);
    _emit(before);
  }

  /// `tracksAdded` from another endpoint: `TrackAdded` per new track; a known
  /// id is updated in place (SPEC §14.2).
  void tracksAdded(server.MediaEvent_TracksAdded event) {
    final endpoint = _knownEndpoint(event.endpointId, 'tracksAdded');
    if (endpoint == null) return;
    for (final MapEntry(key: trackId, value: track)
        in event.trackIdToTrack.entries) {
      final existing = _tracks[trackId];
      if (existing == null) {
        _emit(TrackAdded(_addTrack(endpoint, trackId, track).toContext()));
      } else if (existing.endpointId != endpoint.id) {
        _logger.warn(
          'tracksAdded: track $trackId belongs to ${existing.endpointId}, '
          'not ${endpoint.id}; ignored',
        );
      } else {
        existing
          ..rawMetadata = _trackMetadata(track.metadataJson)
          ..simulcastConfig = _simulcastOf(track);
      }
    }
  }

  /// `tracksRemoved` from another endpoint: `TrackRemoved` per known id.
  void tracksRemoved(server.MediaEvent_TracksRemoved event) {
    final endpoint = _knownEndpoint(event.endpointId, 'tracksRemoved');
    if (endpoint == null) return;
    for (final trackId in event.trackIds) {
      if (!endpoint.trackIds.contains(trackId)) {
        _logger.warn('tracksRemoved: unknown track $trackId; ignored');
        continue;
      }
      _removeTrack(endpoint, trackId);
    }
  }

  /// `trackUpdated` from another endpoint → `TrackUpdated`.
  void trackUpdated(server.MediaEvent_TrackUpdated event) {
    if (event.endpointId == _localPeerId) return;
    final track = _knownTrack(event.trackId, 'trackUpdated');
    if (track == null) return;
    track.rawMetadata = _trackMetadata(event.metadataJson);
    _emit(TrackUpdated(track.toContext()));
  }

  /// `trackVariantSwitched` → `TrackEncodingChanged`.
  void variantSwitched(server.MediaEvent_TrackVariantSwitched event) {
    final track = _knownTrack(event.trackId, 'trackVariantSwitched');
    final variant = _variant(event.variant, 'trackVariantSwitched');
    if (track == null || variant == null) return;
    track.encoding = variant;
    _emit(TrackEncodingChanged(track.toContext()));
  }

  /// `trackVariantEnabled` → `TrackVariantsChanged`.
  void variantEnabled(server.MediaEvent_TrackVariantEnabled event) =>
      _setVariantEnabled(
        event.trackId,
        event.variant,
        enabled: true,
        source: 'trackVariantEnabled',
      );

  /// `trackVariantDisabled` → `TrackVariantsChanged`.
  void variantDisabled(server.MediaEvent_TrackVariantDisabled event) =>
      _setVariantEnabled(
        event.trackId,
        event.variant,
        enabled: false,
        source: 'trackVariantDisabled',
      );

  /// `vadNotification` → `VoiceActivityChanged` (SPEC §14.5).
  void vadNotification(server.MediaEvent_VadNotification event) {
    final track = _knownTrack(event.trackId, 'vadNotification');
    if (track == null) return;
    final status = switch (event.status) {
      server.MediaEvent_VadNotification_Status.STATUS_SPEECH =>
        VadStatus.speech,
      server.MediaEvent_VadNotification_Status.STATUS_SILENCE =>
        VadStatus.silence,
      _ => null,
    };
    if (status == null) {
      _logger.warn('vadNotification: unknown status ${event.status}; ignored');
      return;
    }
    track.vadStatus = status;
    _emit(VoiceActivityChanged(track.toContext()));
  }

  /// Stores mids from an answer for remote tracks (SPEC §10.2). Ids of local
  /// tracks are ignored here.
  void applyAnswerMids(Map<String, String> midToTrackId) {
    for (final MapEntry(key: mid, value: trackId) in midToTrackId.entries) {
      final track = _tracks[trackId];
      if (track == null) continue;
      for (final other in _tracks.values) {
        if (other.mid == mid) other.mid = null;
      }
      track.mid = mid;
    }
  }

  /// Handles `onTrack` (SPEC §14.3): attaches the media to the remote track
  /// with the transceiver's mid and emits `TrackReady`.
  void trackReady(RtcTrackEvent event) {
    final mid = event.mid;
    final track = mid == null
        ? null
        : _tracks.values.where((t) => t.mid == mid).firstOrNull;
    if (track == null) {
      _logger.warn('onTrack for unknown mid $mid; ignored');
      return;
    }
    track
      ..rtcTrack = event.track
      ..rtcStream = event.streams.firstOrNull
      ..kind = event.track.kind;
    _emit(TrackReady(track.toContext()));
  }

  /// Validates and requests a variant (SPEC §14.4). Throws [ArgumentError]
  /// for an unknown track, a non-simulcast track or a variant that is not
  /// enabled; nothing is sent then.
  void setTargetEncoding(String trackId, Variant variant) {
    final track =
        _tracks[trackId] ??
        (throw ArgumentError.value(trackId, 'trackId', 'unknown remote track'));
    final config = track.simulcastConfig;
    if (!config.enabled) {
      throw ArgumentError.value(
        trackId,
        'trackId',
        'the track does not support changing its target variant',
      );
    }
    if (!config.enabledVariants.contains(variant)) {
      throw ArgumentError.value(
        variant,
        'variant',
        'not an enabled variant of $trackId',
      );
    }
    _sendMediaEvent(
      peer.MediaEvent(
        setTargetTrackVariant: peer.MediaEvent_SetTargetTrackVariant(
          trackId: trackId,
          variant: variantToProto(variant),
        ),
      ),
    );
    _emit(TargetTrackEncodingRequested(trackId, variant));
  }

  void _setVariantEnabled(
    String trackId,
    shared.Variant protoVariant, {
    required bool enabled,
    required String source,
  }) {
    final track = _knownTrack(trackId, source);
    final variant = _variant(protoVariant, source);
    if (track == null || variant == null) return;
    final on = {...track.simulcastConfig.enabledVariants};
    enabled ? on.add(variant) : on.remove(variant);
    final off = {...track.simulcastConfig.disabledVariants};
    enabled ? off.remove(variant) : off.add(variant);
    track.simulcastConfig = track.simulcastConfig.copyWith(
      enabledVariants: [
        for (final v in Variant.values)
          if (on.contains(v)) v,
      ],
      disabledVariants: [
        for (final v in Variant.values)
          if (off.contains(v)) v,
      ],
    );
    _emit(TrackVariantsChanged(track.toContext()));
  }

  _RemoteTrack _addTrack(
    _Endpoint endpoint,
    String trackId,
    server.MediaEvent_Track track,
  ) {
    final stored = _RemoteTrack(
      trackId: trackId,
      endpointId: endpoint.id,
      rawMetadata: _trackMetadata(track.metadataJson),
      simulcastConfig: _simulcastOf(track),
    );
    _tracks[trackId] = stored;
    endpoint.trackIds.add(trackId);
    return stored;
  }

  void _removeTrack(_Endpoint endpoint, String trackId) {
    endpoint.trackIds.remove(trackId);
    final removed = _tracks.remove(trackId);
    if (removed != null) _emit(TrackRemoved(removed.toContext()));
  }

  _Endpoint? _knownEndpoint(String id, String source) {
    if (id == _localPeerId) return null;
    final endpoint = _endpoints[id];
    if (endpoint == null) {
      _logger.warn('$source: unknown endpoint $id; ignored');
    }
    return endpoint;
  }

  _RemoteTrack? _knownTrack(String id, String source) {
    final track = _tracks[id];
    if (track == null) _logger.warn('$source: unknown track $id; ignored');
    return track;
  }

  Variant? _variant(shared.Variant variant, String source) {
    final result = variantFromProto(variant);
    if (result == null) _logger.warn('$source: unknown variant $variant');
    return result;
  }

  Metadata _endpointMetadata(String json) =>
      Metadata.fromServerJson(_decode(json));

  Object? _trackMetadata(String json) => _decode(json);

  Object? _decode(String json) => decodeMetadataJson(
    json,
    onError: (e) => _logger.warn('Undecodable metadata JSON: $json', e),
  );

  static SimulcastConfig _simulcastOf(server.MediaEvent_Track track) =>
      simulcastConfigFromProto(
        track.hasSimulcastConfig() ? track.simulcastConfig : null,
      );

  Map<String, RemoteTrackContext> _tracksOf(_Endpoint endpoint) => {
    for (final id in endpoint.trackIds) id: _tracks[id]!.toContext(),
  };

  Peer _peerOf(_Endpoint e) =>
      Peer(id: e.id, type: e.type, metadata: e.metadata, tracks: _tracksOf(e));

  Component _componentOf(_Endpoint e) => Component(
    id: e.id,
    type: e.type,
    metadata: e.metadata,
    tracks: _tracksOf(e),
  );
}

class _Endpoint {
  _Endpoint({
    required this.id,
    required this.type,
    required this.isComponent,
    required this.metadata,
  });

  final String id;
  final String type;
  final bool isComponent;
  Metadata metadata;
  final List<String> trackIds = [];
}

class _RemoteTrack {
  _RemoteTrack({
    required this.trackId,
    required this.endpointId,
    required this.rawMetadata,
    required this.simulcastConfig,
  });

  final String trackId;
  final String endpointId;
  Object? rawMetadata;
  SimulcastConfig simulcastConfig;
  MediaKind? kind;
  RtcMediaTrack? rtcTrack;
  RtcMediaStream? rtcStream;
  VadStatus vadStatus = VadStatus.silence;
  Variant? encoding;
  String? mid;

  RemoteTrackContext toContext() => RemoteTrackContext(
    trackId: trackId,
    endpointId: endpointId,
    rawMetadata: rawMetadata,
    simulcastConfig: simulcastConfig,
    kind: kind,
    rtcTrack: rtcTrack,
    rtcStream: rtcStream,
    vadStatus: vadStatus,
    encoding: encoding,
  );
}
