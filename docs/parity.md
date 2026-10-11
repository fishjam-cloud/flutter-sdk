# Parity with the Fishjam web SDK (`@fishjam-cloud/ts-client`)

Every public API of the web client and its Dart equivalent. "Dropped" entries are intentional; the reason is
given. Behavioral differences are listed in [SPEC §22](../SPEC.md#22-deviations-from-the-web-sdk).

## `FishjamClient` construction and state

| Web SDK | Dart | Notes |
|---|---|---|
| `new FishjamClient({ reconnect, debug, clientType })` | `FishjamClient(debug:, reconnect:, rtcAdapter:, transportFactory:)` | `clientType` dropped: always `flutter`. Adapters are injectable for tests. |
| `reconnect: boolean \| ReconnectConfig` | `ReconnectConfig` (default enabled), `ReconnectConfig.disabled` | delays are `Duration`s |
| `status: 'new' \| 'initialized'` | `status` → `ConnectionStatus` | richer state (SPEC §3.1) |
| `isReconnecting()` | `isReconnecting` | |
| `on(event, cb)` / `off(event, cb)` | `events` (`Stream<FishjamEvent>`), cancel the subscription | sealed classes, exhaustive `switch` |
| `cleanup()` | `dispose()` | |

## Connection

| Web SDK | Dart | Notes |
|---|---|---|
| `connect({ url, token, peerMetadata })` | `connect(url:, token:, peerMetadata:)` | always settles (SPEC §3.2) |
| `leave()` | `leave()` | sends `disconnect`, then tears down (D1) |
| `disconnect()` | `leave()` | one method: leaving always tears down |
| `handleSdkDeprecation(...)` | internal | logged (SPEC §3.2) |
| `getStatistics(selector?)` | `getStatistics([MediaStreamTrack? track])` → `List<RtcStats>` | |
| `getBandwidthEstimation()` | dropped | the server never sends an estimation |

## Room state

| Web SDK | Dart | Notes |
|---|---|---|
| `getRemoteTracks()` | `remoteTracks` → `Map<String, RemoteTrackContext>` | |
| `getRemotePeers()` | `remotePeers` → `Map<String, Peer>` | |
| `getRemoteComponents()` | `remoteComponents` → `Map<String, Component>` | |
| `getLocalPeer()` | `localPeer` → `LocalPeer?` | local tracks are `LocalTrackContext` |

## Local tracks

| Web SDK | Dart | Notes |
|---|---|---|
| `addTrack(track, metadata?, simulcastConfig?, maxBandwidth?)` | `addTrack(MediaStreamTrack track, metadata:, simulcastConfig:, maxBandwidth:)` → `Future<String>` | `flutter_webrtc` track, as returned by `navigator.mediaDevices.getUserMedia` |
| `replaceTrack(trackId, track \| null)` | `replaceTrack(trackId, MediaStreamTrack? track)` | `null` mutes (SPEC §11.3) |
| `removeTrack(trackId)` | `removeTrack(trackId)` | |
| `setTrackBandwidth(trackId, number \| Map)` → `Promise<boolean>` | `setTrackBandwidth(trackId, BandwidthLimit)` → `Future<void>` | `BandwidthLimit.single(kbps)` / `.simulcast({...})` |
| `setEncodingBandwidth(trackId, rid, kbps)` → `Promise<boolean>` | `setEncodingBandwidth(trackId, Variant, kbps)` → `Future<void>` | |
| `enableTrackEncoding(trackId, variant)` | `enableTrackEncoding(trackId, Variant)` | |
| `disableTrackEncoding(trackId, variant)` | `disableTrackEncoding(trackId, Variant)` | emits the correct event (D3) |
| `updatePeerMetadata(metadata)` | `updatePeerMetadata(Object? metadata)` | |
| `updateTrackMetadata(trackId, metadata)` | `updateTrackMetadata(trackId, TrackMetadata?)` | |
| `getLocalTrackAudioLevel(trackId)` → `{ level } \| null` | `getLocalTrackAudioLevel(trackId)` → `double?` | |

## Remote tracks

| Web SDK | Dart | Notes |
|---|---|---|
| `setTargetTrackEncoding(trackId, variant)` | `setTargetTrackEncoding(trackId, Variant)` | validated first, throws `ArgumentError` (D7) |

## Data channels

| Web SDK | Dart | Notes |
|---|---|---|
| `createDataChannels()` | `createDataChannels()` | |
| `publishData(data, { reliable })` | `publishData(Uint8List, reliable:)` | |
| `subscribeData(cb, { reliable })` → unsubscribe fn | `dataStream(reliable:)` → `Stream<Uint8List>` | cancel the subscription to unsubscribe |
| `getDataChannelsReadiness()` | `dataChannelsReady` | |

## Livestreams

| Web SDK | Dart | Notes |
|---|---|---|
| `publishLivestream(stream, url, token, callbacks?)` | `publishLivestream(MediaStream stream, url:, token:)` | connection state is a stream on the result |
| `receiveLivestream(url, token?, callbacks?)` | `receiveLivestream(url:, token:)` | `result.stream` is a `MediaStream` |
| `PublishLivestreamResult.stopPublishing()` / `getStatistics()` | same names | |
| `ReceiveLivestreamResult.stream` / `stop()` / `getStatistics()` | same names | |
| `LivestreamError` (string enum, thrown) | `LivestreamException(LivestreamError)` | |

## Errors, guards and constants

| Web SDK | Dart | Notes |
|---|---|---|
| `AUTH_ERROR_REASONS`, `AuthErrorReason`, `isAuthError` | `AuthErrorReason` enum; `AuthFailed` / `AuthException` | classification is internal (SPEC §4) |
| `normalizeCloseReason` | internal | |
| `JOIN_ERRORS`, `JoinErrorReason`, `isJoinError` | `JoinErrorReason` enum; `JoinFailed` / `JoinException` | `room not found` is an auth error only (D13) |
| `TrackTypeError` | `TrackTypeError` | |
| `MAX_BANDWIDTH_LIMITS` | `singleStreamCapKbps`, `simulcastCapsKbps` | |
| `SIMULCAST_VARIANTS` | `Variant.values` | |
| `resolveTrackBandwidthLimit` | dropped from the public API | internal rule (SPEC §13) |
| `Variant` | `Variant` (`low`, `medium`, `high`) | `rid` = `l`/`m`/`h` |
| `SimulcastConfig` | `SimulcastConfig` | |
| `getLogger` | dropped | use `FishjamClient(debug: true)` |
| `WebRTCEndpoint` | dropped from the public API | internal engine |

## Types

| Web SDK | Dart |
|---|---|
| `Peer` | `Peer` (`id`, `type`, `metadata: Metadata(peer, server)`, `tracks`) |
| `Component` | `Component` |
| `Metadata` | `Metadata` |
| `TrackMetadata` | `TrackMetadata` (`type: TrackType`, `paused`, `displayName`) |
| `FishjamTrackContext` / `TrackContext` | `RemoteTrackContext`, `LocalTrackContext` (sealed `TrackContext`) |
| `TrackContext.endpoint` | `RemoteTrackContext.endpointId` |
| `TrackContext.track` / `.stream` | `track` → `MediaStreamTrack?`, `stream` → `MediaStream?` (`flutter_webrtc` types) |
| `TrackContext.encodingReason` | kept, always `null` (the server does not report one) |
| `VadStatus` | `VadStatus` |
| `EncodingReason` | `EncodingReason` |
| `BandwidthLimit`, `SimulcastBandwidthLimit`, `TrackBandwidthLimit` | `BandwidthLimit` (sealed: `SingleBandwidthLimit`, `SimulcastBandwidthLimit`) |
| `ConnectConfig`, `CreateConfig` | named parameters of `connect()` and the constructor |
| `ReconnectionStatus` | `ConnectionStatus.reconnecting` |
| `DataChannelOptions`, `DataCallback` | `reliable:` parameter, `Stream<Uint8List>` |
| `GenericMetadata` (type parameters) | `Object?` JSON values |

## Events

| Web SDK event | Dart event | Notes |
|---|---|---|
| `connectionStarted` | dropped | the app called `connect()`; see `status` |
| `socketOpen` | dropped | internal |
| `socketError` | dropped | handled as a connection loss (SPEC §4, §6) |
| `socketClose` | `Disconnected(reason, closeCode, closeReason)` or `ReconnectionStarted` | typed `DisconnectReason`: `peerRemoved`, `roomStopped`, `replacedByNewClient`, `authError`, `joinError`, `protocolError`, … |
| `authSuccess` | `AuthSucceeded(roomType)` | |
| `authError` | `AuthFailed(reason)` | |
| `joined` | `Joined(peerId, peers, components)` | |
| `joinError` | `JoinFailed(reason)`; server error events → `ServerError(message)` | |
| `disconnected` | `Disconnected(reason)` | never during reconnection (D9) |
| `disconnectRequested` | dropped | `Disconnected(DisconnectReason.left)` |
| `reconnectionStarted` | `ReconnectionStarted` | |
| `reconnected` | `Reconnected` | always follows a successful reconnection (D2) |
| `reconnectionRetriesLimitReached` | `ReconnectionFailed` | |
| `connectionError` | `ConnectionError(message)` | |
| `peerJoined` / `peerLeft` / `peerUpdated` | `PeerJoined` / `PeerLeft` / `PeerUpdated` | |
| `componentAdded` / `componentRemoved` / `componentUpdated` | `ComponentAdded` / `ComponentRemoved` / `ComponentUpdated` | |
| `trackAdded` / `trackReady` / `trackRemoved` / `trackUpdated` | `TrackAdded` / `TrackReady` / `TrackRemoved` / `TrackUpdated` | |
| `encodingChanged` (client and track context) | `TrackEncodingChanged` | |
| track context `voiceActivityChanged` | `VoiceActivityChanged` | |
| endpoint `trackEncodingEnabled` / `trackEncodingDisabled` (not forwarded by the web client) | `TrackVariantsChanged` | new: lets apps follow available variants |
| `targetTrackEncodingRequested` | `TargetTrackEncodingRequested` | |
| `tracksPriorityChanged` | dropped | never emitted |
| `bandwidthEstimationChanged` | dropped | never emitted |
| `localTrackAdded` / `localTrackRemoved` / `localTrackReplaced` | `LocalTrackAdded` / `LocalTrackRemoved` / `LocalTrackReplaced` | |
| `localTrackMuted` / `localTrackUnmuted` | `LocalTrackMuted` / `LocalTrackUnmuted` | |
| `localTrackBandwidthSet` | `LocalTrackBandwidthSet` | once per call (D4) |
| `localTrackEncodingBandwidthSet` | `LocalTrackEncodingBandwidthSet` | reaches the app (D4) |
| `localTrackEncodingEnabled` / `localTrackEncodingDisabled` | `LocalTrackEncodingEnabled` / `LocalTrackEncodingDisabled` | |
| `localPeerMetadataChanged` | `LocalPeerMetadataChanged` | |
| `localTrackMetadataChanged` | `LocalTrackMetadataChanged` | |
| `dataChannelsReady` / `dataChannelsError` | `DataChannelsReady` / `DataChannelsError` | |
