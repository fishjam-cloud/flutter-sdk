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
  NegotiationState _state = NegotiationState.idle;
  bool _restartPending = false;

  /// Current state.
  NegotiationState get state => _state;

  /// Whether an ICE restart was requested during the current cycle; it is
  /// sent when the cycle ends (SPEC §8.2, D19).
  bool get restartPending => _restartPending;

  /// Whether a command may start now (SPEC §8.3 rules 1, 2): anything in
  /// [NegotiationState.idle], only batchable commands in
  /// [NegotiationState.requested], nothing while an offer is in flight.
  bool canStart({required bool batchable}) => switch (_state) {
    NegotiationState.idle => true,
    NegotiationState.requested => batchable,
    NegotiationState.offerSent => false,
  };

  /// Applies [input] and returns the effects to perform, in order.
  ///
  /// Throws [StateError] when a command starts while an offer is in flight
  /// (callers check [canStart] first).
  List<NegotiationEffect> handle(NegotiationInput input) {
    switch ((input, _state)) {
      case (NegotiationInput.commandStarted, NegotiationState.idle):
        _state = NegotiationState.requested;
        return const [NegotiationEffect.sendRenegotiateTracks];
      case (NegotiationInput.commandStarted, NegotiationState.requested):
        return const [];
      case (NegotiationInput.commandStarted, NegotiationState.offerSent):
        throw StateError('A command cannot start while an offer is in flight');
      case (NegotiationInput.remoteTracksAdded, NegotiationState.idle):
        _state = NegotiationState.requested;
        return const [];
      case (NegotiationInput.remoteTracksAdded, _):
        return const [];
      case (NegotiationInput.offerSent, _):
        _state = NegotiationState.offerSent;
        return const [];
      case (NegotiationInput.answerApplied, NegotiationState.offerSent):
        if (_restartPending) {
          _restartPending = false;
          _state = NegotiationState.requested;
          return const [
            NegotiationEffect.sendRenegotiateTracks,
            NegotiationEffect.processNextCommand,
          ];
        }
        _state = NegotiationState.idle;
        return const [NegotiationEffect.processNextCommand];
      case (NegotiationInput.answerApplied, _):
        return const [];
      case (NegotiationInput.iceDisconnected, NegotiationState.offerSent):
        _restartPending = true;
        return const [];
      case (NegotiationInput.iceDisconnected, _):
        _state = NegotiationState.requested;
        return const [NegotiationEffect.sendRenegotiateTracks];
    }
  }

  /// Back to [NegotiationState.idle] (teardown, or an aborted cycle).
  void reset() {
    _state = NegotiationState.idle;
    _restartPending = false;
  }
}
