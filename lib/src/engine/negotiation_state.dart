/// The negotiation state machine (SPEC §8.1, §8.2).
///
/// Owner: **Engine** agent. This is the only place that decides whether a
/// negotiation is in progress.
library;

/// Negotiation states (SPEC §8.1).
enum NegotiationState {
  /// No negotiation in flight; commands may start.
  idle,

  /// `renegotiateTracks` sent or a remote `tracksAdded` seen; waiting for
  /// `offerData`.
  requested,

  /// `sdpOffer` sent; waiting for `sdpAnswer`.
  offerSent,
}

/// Inputs of the state machine (SPEC §8.2).
enum NegotiationInput {
  /// A negotiating command started.
  commandStarted,

  /// `tracksAdded` from a remote endpoint.
  remoteTracksAdded,

  /// `offerData` handled and `sdpOffer` sent.
  offerSent,

  /// `sdpAnswer` applied.
  answerApplied,

  /// ICE connection state became `disconnected`.
  iceDisconnected,
}

/// What the caller must do after a transition.
enum NegotiationEffect {
  /// Nothing.
  none,

  /// Send `renegotiateTracks`.
  sendRenegotiateTracks,

  /// Start the next queued command.
  processNextCommand,
}

/// Pure transition logic: no I/O, so it can be tested exhaustively.
///
/// Owner: Engine.
class NegotiationStateMachine {
  /// Current state.
  NegotiationState get state => throw UnimplementedError('Engine');

  /// Applies [input] and returns the effects to perform, in order.
  List<NegotiationEffect> handle(NegotiationInput input) =>
      throw UnimplementedError('Engine');

  /// Back to [NegotiationState.idle] (teardown).
  void reset() => throw UnimplementedError('Engine');
}
