Owner: **Tracks**. Local and remote track state, simulcast encodings, bandwidth rules, variants and voice activity (SPEC §11–§14); never drives negotiation.

- `LocalTrack` methods act on the sender only and emit nothing. The `LocalTrackRegistry` methods
  `replaceTrack`, `setTrackBandwidth`, `setEncodingBandwidth`, `enable/disableTrackEncoding` and `audioLevel`
  implement SPEC §11.3–§11.5 and §18 end to end (resolution, sender, media events, client events); callers use
  those and add no events of their own.
- `addTrack` resolves video limits with `resolveVideoBandwidth` and gives audio `BandwidthLimit.unlimited`;
  `setTrackBandwidth` uses `resolveTrackBandwidth` (audio as given, video against the caps) (SPEC §13.4).
- `RemoteStore` emits every remote event itself; the engine only forwards server events, answer mids and
  `onTrack`.
- Nothing here is reentrant: callers must not overlap operations on one track. The engine serializes them
  (command queue and serial media event handling, SPEC §7, §8.3).
