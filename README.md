# Fishjam Flutter client

Flutter SDK for [Fishjam](https://fishjam.io), the real-time video and audio streaming toolkit. Join a room
with a peer token, publish camera and microphone tracks, receive other peers' media and exchange data, on iOS
and Android. Media is handled by [`flutter_webrtc`](https://pub.dev/packages/flutter_webrtc): the SDK takes
and returns its `MediaStreamTrack` / `MediaStream` types, ready for `RTCVideoView`.

## Install

```sh
flutter pub add fishjam_client flutter_webrtc
```

## Platform setup

The SDK uses the camera, the microphone and the network through `flutter_webrtc`.

**iOS** (deployment target 13.0 or newer): add usage strings to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>The camera is used in video calls.</string>
<key>NSMicrophoneUsageDescription</key>
<string>The microphone is used in calls.</string>
```

**Android**: set `minSdk` to 23 or newer in `android/app/build.gradle(.kts)` and add the permissions to
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

`getUserMedia` asks the user for camera and microphone access when it is first called.

## Quickstart

Your backend creates the peer with a Fishjam server SDK and gives the app the Fishjam URL and a **peer
token** (never ship the management token in an app). Then:

```dart
import 'dart:convert';

import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

final client = FishjamClient();

// Subscribe before connect(): events are not replayed to late listeners.
client.events.listen((event) {
  switch (event) {
    case TrackReady(:final track):
      // Remote media arrived: renderer.srcObject = track.stream;
      break;
    case TrackRemoved(:final track):
      // Stop rendering track.trackId.
      break;
    case Disconnected(:final reason):
      // The session ended; see reason.
      break;
    default:
  }
});

await client.connect(
  url: fishjamUrlFromId(fishjamId), // or your Fishjam server's URL
  token: peerToken,
  peerMetadata: {'name': 'Alice'},
);

final media = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
final camera = media.getVideoTracks().first;
final cameraId = await client.addTrack(
  camera,
  metadata: const TrackMetadata(type: TrackType.camera),
);
await client.addTrack(
  media.getAudioTracks().first,
  metadata: const TrackMetadata(type: TrackType.microphone),
);

await client.replaceTrack(cameraId, null); // mute the camera
await client.replaceTrack(cameraId, camera); // unmute it

await client.createDataChannels();
client.dataStream(reliable: true).listen((bytes) => print(utf8.decode(bytes)));
client.publishData(utf8.encode('hello'), reliable: true);

await client.leave();
await client.dispose();
```

`connect()` completes when the room is joined and throws `AuthException`, `JoinException` or
`ConnectionException` otherwise (`ArgumentError` for a URL that is not ws, wss, http or https).

A lost connection is re-established automatically (`ReconnectConfig`):

- From `ReconnectionStarted` until `Reconnected` the status is `reconnecting` and calls that need the
  session (track operations, metadata updates, `createDataChannels()`) fail at once with `StateError`.
- Before the new `Joined`, the remote tracks and peers you knew are reported with `TrackRemoved` and
  `PeerLeft` / `ComponentRemoved`; the new `Joined` lists the room as it is now.
- Local tracks are re-published only with `ReconnectConfig(addTracksOnReconnect: true)`, under new track ids
  (the old ids get `LocalTrackRemoved`). Create the data channels again after `Reconnected`.

`replaceTrack(id, null)` mutes by sending nothing; the device keeps capturing until you stop the track.

Livestreams without a room use `publishLivestream` (WHIP) and `receiveLivestream` (WHEP).

For prototyping without a backend, the Fishjam dashboard offers a Sandbox API that returns peer tokens. It is
unauthenticated: never use it in production. The [example app](example/) shows both flows.

More: the [Fishjam documentation](https://docs.fishjam.io), [SPEC.md](SPEC.md) (the behavioral contract) and
[docs/parity.md](docs/parity.md) (mapping from the Fishjam web SDK).

## Development

See [AGENTS.md](AGENTS.md).

## License

Apache 2.0, see [LICENSE](LICENSE).
