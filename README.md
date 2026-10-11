# Fishjam Flutter client

Flutter SDK for [Fishjam](https://fishjam.io), the real-time video and audio streaming toolkit. Join a room
with a peer token, publish camera, microphone and screen tracks, receive other peers' media and exchange data,
on iOS and Android.

> Status: under construction. The public API is defined but not implemented yet; see [SPEC.md](SPEC.md) for
> the behavioral contract and [docs/parity.md](docs/parity.md) for the mapping from the Fishjam web SDK.

```dart
final client = FishjamClient();
client.events.listen((event) {
  switch (event) {
    case TrackReady(:final track):
      // render track.stream
    default:
  }
});
await client.connect(url: fishjamUrl, token: peerToken, peerMetadata: {'name': 'Alice'});
```

Peer tokens are created by your backend with a Fishjam server SDK. See the
[Fishjam documentation](https://docs.fishjam.io).

## Development

See [AGENTS.md](AGENTS.md).

## License

Apache 2.0, see [LICENSE](LICENSE).
