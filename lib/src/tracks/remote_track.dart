/// Remote endpoints and tracks (SPEC §14).
///
/// Owner: **Tracks** agent. The Engine forwards server media events here;
/// this module owns all remote state and emits the remote events.
library;

// Constructor fields are kept for the Tracks implementation.
// ignore_for_file: unused_field

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/peer/peer.pb.dart'
    as peer;
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// Remote endpoints and tracks of a session.
///
/// Every method logs and ignores unknown endpoint or track ids (SPEC §7).
///
/// Owner: Tracks.
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

  /// Loads the snapshot from `connected`, skipping [localPeerId]. Emits
  /// nothing (SPEC §14.1).
  void loadConnected(
    server.MediaEvent_Connected connected,
    String localPeerId,
  ) => throw UnimplementedError('Tracks');

  /// Current peers.
  List<Peer> get peers => throw UnimplementedError('Tracks');

  /// Current components.
  List<Component> get components => throw UnimplementedError('Tracks');

  /// Current remote tracks by id.
  Map<String, RemoteTrackContext> get tracks =>
      throw UnimplementedError('Tracks');

  /// `endpointAdded`.
  void endpointAdded(server.MediaEvent_EndpointAdded event) =>
      throw UnimplementedError('Tracks');

  /// `endpointUpdated`.
  void endpointUpdated(server.MediaEvent_EndpointUpdated event) =>
      throw UnimplementedError('Tracks');

  /// `endpointRemoved` for another endpoint.
  void endpointRemoved(server.MediaEvent_EndpointRemoved event) =>
      throw UnimplementedError('Tracks');

  /// `tracksAdded` from another endpoint.
  void tracksAdded(server.MediaEvent_TracksAdded event) =>
      throw UnimplementedError('Tracks');

  /// `tracksRemoved` from another endpoint.
  void tracksRemoved(server.MediaEvent_TracksRemoved event) =>
      throw UnimplementedError('Tracks');

  /// `trackUpdated` from another endpoint.
  void trackUpdated(server.MediaEvent_TrackUpdated event) =>
      throw UnimplementedError('Tracks');

  /// `trackVariantSwitched`.
  void variantSwitched(server.MediaEvent_TrackVariantSwitched event) =>
      throw UnimplementedError('Tracks');

  /// `trackVariantEnabled`.
  void variantEnabled(server.MediaEvent_TrackVariantEnabled event) =>
      throw UnimplementedError('Tracks');

  /// `trackVariantDisabled`.
  void variantDisabled(server.MediaEvent_TrackVariantDisabled event) =>
      throw UnimplementedError('Tracks');

  /// `vadNotification`.
  void vadNotification(server.MediaEvent_VadNotification event) =>
      throw UnimplementedError('Tracks');

  /// Stores mids from an answer for remote tracks (SPEC §10.2).
  void applyAnswerMids(Map<String, String> midToTrackId) =>
      throw UnimplementedError('Tracks');

  /// Handles `onTrack` (SPEC §14.3).
  void trackReady(RtcTrackEvent event) => throw UnimplementedError('Tracks');

  /// Validates and requests a variant (SPEC §14.4). Throws [ArgumentError].
  void setTargetEncoding(String trackId, Variant variant) =>
      throw UnimplementedError('Tracks');
}
