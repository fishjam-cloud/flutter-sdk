## 0.31.0

Initial release.

- `FishjamClient`: join a room with a peer token (`connect`), `leave`, connection status and typed events
  (sealed `FishjamEvent` classes).
- Local tracks on `flutter_webrtc` types: add, remove, replace, mute/unmute, metadata, simulcast with
  per-layer enable/disable and bandwidth limits, local audio level.
- Remote peers, components and tracks with metadata, simulcast variant selection and voice activity.
- Reliable and lossy data channels.
- Automatic reconnection (`ReconnectConfig`), optionally re-publishing local tracks.
- Periodic statistics reporting to the server; `getStatistics()`.
- Livestreams over WHIP (`publishLivestream`) and WHEP (`receiveLivestream`).
- Behavioral differences from the Fishjam web SDK are listed in SPEC.md §22.
