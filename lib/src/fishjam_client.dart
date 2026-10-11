/// The public client facade.
///
/// Owner: **Integrator** (phase 3). It wires Signaling, Engine, Tracks, Data
/// and Stats together; it holds no protocol logic of its own.
library;

// Constructor fields are kept for the Integrator implementation.
// ignore_for_file: unused_field

import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';
import 'package:fishjam_client/src/signaling/transport.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStreamTrack;
import 'package:meta/meta.dart';

/// Connects to a Fishjam room and exchanges media and data.
///
/// ```dart
/// final client = FishjamClient();
/// client.events.listen((event) {
///   switch (event) {
///     case TrackReady(:final track): render(track);
///     default:
///   }
/// });
/// await client.connect(url: fishjamUrl, token: peerToken);
/// ```
class FishjamClient {
  /// Creates a client. The adapter and transport factory exist for tests;
  /// they default to the `flutter_webrtc` adapter and `dart:io` WebSockets.
  ///
  /// This facade converts between `flutter_webrtc` types and the internal
  /// `RtcMediaTrack` seam (`wrapNativeTrack` / `nativeTrackOf`).
  FishjamClient({
    this.debug = false,
    this.reconnect = const ReconnectConfig(),
    @visibleForTesting this._rtcAdapter,
    @visibleForTesting this._transportFactory,
  });

  /// Whether SDK logs are emitted (SPEC §21).
  final bool debug;

  /// Reconnection settings (SPEC §6).
  final ReconnectConfig reconnect;

  final RtcAdapter? _rtcAdapter;
  final SignalingTransportFactory? _transportFactory;

  /// All client events (broadcast).
  Stream<FishjamEvent> get events => throw UnimplementedError('Integrator');

  /// Current connection status (SPEC §3.1).
  ConnectionStatus get status => throw UnimplementedError('Integrator');

  /// Whether a reconnection is in progress.
  bool get isReconnecting => throw UnimplementedError('Integrator');

  /// Joins the room (SPEC §3.2). Completes on `Joined`; throws
  /// `AuthException`, `JoinException` or `ConnectionException`.
  Future<void> connect({
    required String url,
    required String token,
    Object? peerMetadata,
  }) => throw UnimplementedError('Integrator');

  /// Leaves the room gracefully (SPEC §3.3).
  Future<void> leave() => throw UnimplementedError('Integrator');

  /// Publishes [track] (SPEC §11.1); returns its track id. Throws
  /// `TrackTypeError` for video in an audio-only room.
  Future<String> addTrack(
    MediaStreamTrack track, {
    TrackMetadata? metadata,
    SimulcastConfig simulcastConfig = const SimulcastConfig.disabled(),
    BandwidthLimit maxBandwidth = BandwidthLimit.unlimited,
  }) => throw UnimplementedError('Integrator');

  /// Unpublishes a track (SPEC §11.2).
  Future<void> removeTrack(String trackId) =>
      throw UnimplementedError('Integrator');

  /// Replaces, mutes (`null`) or unmutes a track's media (SPEC §11.3).
  Future<void> replaceTrack(String trackId, MediaStreamTrack? track) =>
      throw UnimplementedError('Integrator');

  /// Sets a track's bandwidth limit in kbps (SPEC §11.5, §13).
  Future<void> setTrackBandwidth(String trackId, BandwidthLimit bandwidth) =>
      throw UnimplementedError('Integrator');

  /// Sets one simulcast layer's limit in kbps (SPEC §11.5, §13).
  Future<void> setEncodingBandwidth(
    String trackId,
    Variant variant,
    int kbps,
  ) => throw UnimplementedError('Integrator');

  /// Starts sending a simulcast layer (SPEC §11.4).
  Future<void> enableTrackEncoding(String trackId, Variant variant) =>
      throw UnimplementedError('Integrator');

  /// Stops sending a simulcast layer (SPEC §11.4).
  Future<void> disableTrackEncoding(String trackId, Variant variant) =>
      throw UnimplementedError('Integrator');

  /// Asks the server to send [variant] of a remote track (SPEC §14.4).
  void setTargetTrackEncoding(String trackId, Variant variant) =>
      throw UnimplementedError('Integrator');

  /// Updates this peer's metadata (SPEC §11.6).
  void updatePeerMetadata(Object? metadata) =>
      throw UnimplementedError('Integrator');

  /// Updates a local track's metadata (SPEC §11.6).
  void updateTrackMetadata(String trackId, TrackMetadata? metadata) =>
      throw UnimplementedError('Integrator');

  /// This client in the room; `null` before `Joined`.
  LocalPeer? get localPeer => throw UnimplementedError('Integrator');

  /// Other peers by id.
  Map<String, Peer> get remotePeers => throw UnimplementedError('Integrator');

  /// Components by id.
  Map<String, Component> get remoteComponents =>
      throw UnimplementedError('Integrator');

  /// Remote tracks by id.
  Map<String, RemoteTrackContext> get remoteTracks =>
      throw UnimplementedError('Integrator');

  /// Peer connection statistics, optionally for one track.
  Future<List<RtcStats>> getStatistics([MediaStreamTrack? track]) =>
      throw UnimplementedError('Integrator');

  /// Audio level (0.0–1.0) of a local audio track (SPEC §18).
  Future<double?> getLocalTrackAudioLevel(String trackId) =>
      throw UnimplementedError('Integrator');

  /// Creates the reliable and lossy data channels (SPEC §16).
  Future<void> createDataChannels() => throw UnimplementedError('Integrator');

  /// Whether both data channels are open.
  bool get dataChannelsReady => throw UnimplementedError('Integrator');

  /// Sends [data] to every other peer (SPEC §16).
  void publishData(Uint8List data, {required bool reliable}) =>
      throw UnimplementedError('Integrator');

  /// Data received from other peers on one channel (SPEC §16).
  Stream<Uint8List> dataStream({required bool reliable}) =>
      throw UnimplementedError('Integrator');

  /// Leaves (if connected) and releases every resource. The client cannot
  /// be used afterwards.
  Future<void> dispose() => throw UnimplementedError('Integrator');
}
