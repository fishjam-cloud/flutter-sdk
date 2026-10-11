import 'package:fishjam_client/src/engine/negotiation_state.dart';
import 'package:flutter_test/flutter_test.dart';

const NegotiationEffect _renegotiate = NegotiationEffect.sendRenegotiateTracks;
const NegotiationEffect _next = NegotiationEffect.processNextCommand;

NegotiationStateMachine _in(NegotiationState state) {
  final machine = NegotiationStateMachine();
  switch (state) {
    case NegotiationState.idle:
      break;
    case NegotiationState.requested:
      machine.handle(NegotiationInput.commandStarted);
    case NegotiationState.offerSent:
      machine
        ..handle(NegotiationInput.commandStarted)
        ..handle(NegotiationInput.offerSent);
  }
  expect(machine.state, state);
  return machine;
}

void main() {
  group('NegotiationStateMachine (SPEC §8.2)', () {
    test('starts idle', () {
      expect(NegotiationStateMachine().state, NegotiationState.idle);
    });

    test('idle + command started -> requested, sends renegotiateTracks', () {
      final m = _in(NegotiationState.idle);
      expect(m.handle(NegotiationInput.commandStarted), [_renegotiate]);
      expect(m.state, NegotiationState.requested);
    });

    test('requested + command started rides the pending cycle', () {
      final m = _in(NegotiationState.requested);
      expect(m.handle(NegotiationInput.commandStarted), isEmpty);
      expect(m.state, NegotiationState.requested);
    });

    test('offerSent + command started is a programming error', () {
      final m = _in(NegotiationState.offerSent);
      expect(() => m.handle(NegotiationInput.commandStarted), throwsStateError);
      expect(m.state, NegotiationState.offerSent);
    });

    test('idle + remote tracksAdded -> requested, sends nothing', () {
      final m = _in(NegotiationState.idle);
      expect(m.handle(NegotiationInput.remoteTracksAdded), isEmpty);
      expect(m.state, NegotiationState.requested);
    });

    test('remote tracksAdded does not leave requested or offerSent', () {
      for (final s in [
        NegotiationState.requested,
        NegotiationState.offerSent,
      ]) {
        final m = _in(s);
        expect(m.handle(NegotiationInput.remoteTracksAdded), isEmpty);
        expect(m.state, s);
      }
    });

    test('offer sent from any state -> offerSent', () {
      for (final s in NegotiationState.values) {
        final m = _in(s);
        expect(m.handle(NegotiationInput.offerSent), isEmpty);
        expect(m.state, NegotiationState.offerSent);
      }
    });

    test('offerSent + answer applied -> idle, processes the next command', () {
      final m = _in(NegotiationState.offerSent);
      expect(m.handle(NegotiationInput.answerApplied), [_next]);
      expect(m.state, NegotiationState.idle);
    });

    test('answer applied outside offerSent changes nothing', () {
      for (final s in [NegotiationState.idle, NegotiationState.requested]) {
        final m = _in(s);
        expect(m.handle(NegotiationInput.answerApplied), isEmpty);
        expect(m.state, s);
      }
    });

    test('ICE disconnected in idle or requested sends renegotiateTracks', () {
      for (final s in [NegotiationState.idle, NegotiationState.requested]) {
        final m = _in(s);
        expect(m.handle(NegotiationInput.iceDisconnected), [_renegotiate]);
        expect(m.state, NegotiationState.requested);
      }
    });

    test('ICE disconnected in offerSent is deferred to the end of the cycle '
        '(D19)', () {
      final m = _in(NegotiationState.offerSent);
      expect(m.handle(NegotiationInput.iceDisconnected), isEmpty);
      expect(m.handle(NegotiationInput.iceDisconnected), isEmpty);
      expect(m.state, NegotiationState.offerSent);
      expect(m.restartPending, isTrue);

      expect(m.handle(NegotiationInput.answerApplied), [_renegotiate, _next]);
      expect(m.state, NegotiationState.requested);
      expect(m.restartPending, isFalse);

      // Only one restart was remembered.
      m.handle(NegotiationInput.offerSent);
      expect(m.handle(NegotiationInput.answerApplied), [_next]);
      expect(m.state, NegotiationState.idle);
    });

    test('canStart: idle starts anything, requested only batchable, '
        'offerSent nothing (SPEC §8.3)', () {
      final idle = _in(NegotiationState.idle);
      expect(idle.canStart(batchable: true), isTrue);
      expect(idle.canStart(batchable: false), isTrue);
      final requested = _in(NegotiationState.requested);
      expect(requested.canStart(batchable: true), isTrue);
      expect(requested.canStart(batchable: false), isFalse);
      final offerSent = _in(NegotiationState.offerSent);
      expect(offerSent.canStart(batchable: true), isFalse);
      expect(offerSent.canStart(batchable: false), isFalse);
    });

    test('reset goes back to idle and forgets a deferred restart', () {
      final m = _in(NegotiationState.offerSent)
        ..handle(NegotiationInput.iceDisconnected)
        ..reset();
      expect(m.state, NegotiationState.idle);
      expect(m.restartPending, isFalse);
    });
  });
}
