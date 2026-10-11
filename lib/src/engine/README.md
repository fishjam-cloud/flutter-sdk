Owner: **Engine**. Per-session media engine: serialized media event dispatch, the negotiation state machine, the command queue, the peer connection and ICE (SPEC §7–§10); delegates track state to `tracks/` and channels to `data/`.

- One `RtcEngine` per session (a reconnection creates a new one). Media events (`handleServerEvent`) and
  commands run on one `SerialExecutor`, so each event is handled completely before the next.
- The session owner wires: `connect(metadata)` after `authenticated`; server media events into
  `handleServerEvent`; `joined` for `Joined`; `sendDisconnect()` then `close()` on leave. It acts on the
  callbacks: `onServerError` (the engine already emitted `ServerError`; leave with `serverError`),
  `onLocalPeerRemoved` (tear down with `peerRemoved`), `onConnectionFailed` (the engine already emitted
  `ConnectionError`; a retryable loss).
- The audio-only `TrackTypeError` check (SPEC §20) is the caller's: the engine does not know the room type.
- `negotiate(apply)` (Data) is a batchable command that completes after the answer; waiting for the channels to
  open is the caller's. `ensurePeerConnection()` runs on the executor; do not call it from inside `apply`.
