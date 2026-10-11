Owner: **Data & Stats**. The `reliable` and `lossy` data channels and `ChannelMessage` framing (SPEC §16); negotiation goes through `RtcEngine.negotiate`.

Lifecycle for the owner (facade):

- One `DataChannelManager` per client; `dataStream` subscriptions survive sessions.
- On teardown, call `close()` **before** closing the engine, so a pending `createChannels()` is cancelled
  silently (a `StateError('disconnected')` from the engine is also treated as a silent cancel).
- On client dispose, call `dispose()`: it closes the channels and ends every `dataStream`.
