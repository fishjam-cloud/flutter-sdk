# Integration tests

`room_test.dart` runs on an iOS simulator against a real Fishjam server: two clients join one room,
exchange messages on both data channels, one publishes its microphone and the other receives `TrackReady`
for it, then both leave. The tests live in the example app because they need a host app with the native
WebRTC plugin.

## Prerequisites

- macOS with Xcode and at least one iPhone simulator.
- The toolchain from `mise.toml` (`mise install`).
- A Fishjam server reachable from the simulator. The simulator shares the host's network, so a server
  running locally is reachable at `http://localhost:<port>`. The test needs:
  - `FISHJAM_URL`: the server's base URL (the one a server SDK uses; the client connects to the same URL).
  - `FISHJAM_MANAGEMENT_TOKEN`: the server's management token. The test uses it like an app backend would:
    `POST /room` to create a room and `POST /room/<id>/peer` (`{"type": "webrtc"}`) to get one peer token per
    client; the room is deleted at the end. Peer tokens are therefore created by the test itself.

## Run

```sh
FISHJAM_URL=http://localhost:<port> FISHJAM_MANAGEMENT_TOKEN=<token> tool/run_integration.sh
```

The script boots the first available iPhone simulator (or the one passed as an argument, by name or
UDID), grants the example app microphone and camera access so no permission dialog blocks the run, and
runs `flutter test integration_test` in `example/`. The simulator captures audio from the host's input
device.
