# Integration tests

`room_test.dart` runs on an iOS simulator against a real Fishjam server: two clients join one room,
exchange messages on both data channels, one publishes its microphone and the other receives `TrackReady`
for it, then both leave. The tests live in the example app because they need a host app with the native
WebRTC plugin.

## Prerequisites

- macOS with Xcode and at least one iPhone simulator.
- The toolchain from `mise.toml` (`mise install`).
- A Fishjam instance reachable from the simulator: Fishjam Cloud (easiest) or a local server. The test needs:
  - `FISHJAM_ID`: your Fishjam ID from the Fishjam dashboard, resolved with `fishjamUrlFromId` exactly like
    the server SDKs do. It may instead be a full server URL (e.g. `http://localhost:<port>`; the simulator
    shares the host's network). A URL must serve both the REST API (`/room`, used by the test as a backend)
    and the peer WebSocket (`/socket/peer/websocket`, used by the clients) on that one origin.
    `FISHJAM_URL` is accepted as an alias.
  - `FISHJAM_MANAGEMENT_TOKEN`: the server's management token. The test uses it like an app backend would:
    `POST /room` to create a room and `POST /room/<id>/peer` (`{"type": "webrtc"}`) to get one peer token per
    client; the room is deleted at the end. Peer tokens are therefore created by the test itself.

- Media and data channels flow over WebRTC, not over the WebSocket: the simulator must reach the server's
  media (ICE) ports over UDP. Fishjam Cloud handles this. With a local server, make sure those ports are bound on an address the host
  can reach and are not blocked by a firewall; otherwise joining works but data channels never open and no
  `TrackReady` arrives.

## Run

```sh
# Fishjam Cloud
FISHJAM_ID=<fishjam id> FISHJAM_MANAGEMENT_TOKEN=<management token> tool/run_integration.sh

# Local server
FISHJAM_ID=http://localhost:<port> FISHJAM_MANAGEMENT_TOKEN=<token> tool/run_integration.sh
```

The script boots the first available iPhone simulator (or the one passed as an argument, by UDID), builds
and installs the test app, grants it microphone and camera access so no permission dialog blocks the run
(a failed grant is reported as a warning: the run may then stop at a permission dialog), and runs
`flutter test integration_test` in `example/`. The simulator captures audio from the host's input
device.
