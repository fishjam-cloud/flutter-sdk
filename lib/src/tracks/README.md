Owner: **Tracks**. Local and remote track state, simulcast encodings, bandwidth rules, variants and voice activity (SPEC §11–§14); never drives negotiation.

- `LocalTrack` methods act on the sender only and emit nothing. The `LocalTrackRegistry` methods
  `replaceTrack`, `setTrackBandwidth`, `setEncodingBandwidth`, `enable/disableTrackEncoding` and `audioLevel`
  implement SPEC §11.3–§11.5 and §18 end to end (resolution, sender, media events, client events); callers use
  those and add no events of their own.
- `resolveTrackBandwidth` (audio as is, video against the caps) is what `addTrack` and `setTrackBandwidth` use;
  `addTrack` passes `BandwidthLimit.unlimited` for audio (SPEC §13.4).
- `RemoteStore` emits every remote event itself; the engine only forwards server events, answer mids and
  `onTrack`.
