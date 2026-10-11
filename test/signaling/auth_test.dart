import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/signaling/auth.dart';
import 'package:fishjam_client/src/signaling/transport.dart';
import 'package:flutter_test/flutter_test.dart';

CloseReason _classify(String? reason, {int? code = 1000}) =>
    classifyClose(TransportClosed(code: code, reason: reason));

void main() {
  group('peerSocketUrl (SPEC §2.1)', () {
    test('appends the socket path', () {
      expect(
        peerSocketUrl('ws://fishjam.test'),
        Uri.parse('ws://fishjam.test/socket/peer/websocket'),
      );
    });

    test('does not duplicate a trailing slash', () {
      expect(
        peerSocketUrl('wss://fishjam.test/app/'),
        Uri.parse('wss://fishjam.test/app/socket/peer/websocket'),
      );
    });

    test('keeps a path without a trailing slash', () {
      expect(
        peerSocketUrl('wss://fishjam.test/app'),
        Uri.parse('wss://fishjam.test/app/socket/peer/websocket'),
      );
    });

    test('turns http and https URLs into ws and wss', () {
      expect(
        peerSocketUrl('https://fishjam.test/app'),
        Uri.parse('wss://fishjam.test/app/socket/peer/websocket'),
      );
      expect(
        peerSocketUrl('http://localhost:8080/'),
        Uri.parse('ws://localhost:8080/socket/peer/websocket'),
      );
    });
  });

  test('normalizeCloseReason trims and lowercases (SPEC §4)', () {
    expect(normalizeCloseReason('  Invalid Token \n'), 'invalid token');
    expect(normalizeCloseReason(''), '');
  });

  group('classifyClose (SPEC §4)', () {
    for (final reason in AuthErrorReason.values) {
      test('"${reason.wireReason}" is an auth error', () {
        final closed = _classify(' ${reason.wireReason.toUpperCase()} ');
        expect(closed, isA<AuthClose>());
        expect((closed as AuthClose).authError, reason);
        expect(closed.code, 1000);
        expect(closed.reason, ' ${reason.wireReason.toUpperCase()} ');
        expect(closed.isRetryable, isFalse);
      });
    }

    for (final reason in JoinErrorReason.values) {
      test('"${reason.wireReason}" is a join error', () {
        final closed = _classify(reason.wireReason, code: 1011);
        expect(closed, isA<JoinClose>());
        expect((closed as JoinClose).joinError, reason);
        expect(closed.code, 1011);
        expect(closed.isRetryable, isFalse);
      });
    }

    for (final reason in SessionEndReason.values) {
      test('"${reason.wireReason}" ends the session', () {
        final closed = _classify(reason.wireReason.toUpperCase());
        expect(closed, isA<SessionEndedClose>());
        expect((closed as SessionEndedClose).sessionEnd, reason);
        expect(closed.isRetryable, isFalse);
      });
    }

    for (final reason in ['unauthenticated', 'Malformed protobuf']) {
      test('"$reason" is a protocol error', () {
        final closed = _classify(reason);
        expect(closed, isA<ProtocolErrorClose>());
        expect(closed.isRetryable, isFalse);
      });
    }

    test('room not found is an auth error only (D13)', () {
      expect(_classify('Room not found'), isA<AuthClose>());
    });

    test('anything else is retryable', () {
      for (final reason in ['', 'Internal server error', 'boom', null]) {
        final closed = _classify(reason, code: 1011);
        expect(closed, isA<RetryableClose>(), reason: '$reason');
        expect(closed.isRetryable, isTrue);
        expect(closed.code, 1011);
      }
    });

    test('a close without a close frame is always retryable', () {
      final error = StateError('lost');
      final closed = classifyClose(
        TransportClosed(reason: 'invalid token', error: error),
      );
      expect(closed, isA<RetryableClose>());
      expect((closed as RetryableClose).error, error);
      expect(closed.code, isNull);
    });
  });

  group('terminal mapping (SPEC §3.2, §4)', () {
    test('disconnectReasonFor maps every close class', () {
      expect(
        disconnectReasonFor(const AuthClose(AuthErrorReason.invalidToken)),
        DisconnectReason.authError,
      );
      expect(
        disconnectReasonFor(const JoinClose(JoinErrorReason.nodeNotFound)),
        DisconnectReason.joinError,
      );
      expect(
        disconnectReasonFor(
          const SessionEndedClose(SessionEndReason.replacedByNewClient),
        ),
        DisconnectReason.replacedByNewClient,
      );
      expect(
        disconnectReasonFor(const ProtocolErrorClose()),
        DisconnectReason.protocolError,
      );
      expect(
        disconnectReasonFor(const RetryableClose()),
        DisconnectReason.connectionLost,
      );
    });

    test('disconnectedFor carries the close code and reason', () {
      final event = disconnectedFor(
        const SessionEndedClose(
          SessionEndReason.roomStopped,
          code: 1000,
          reason: 'Room stopped',
        ),
      );
      expect(event.reason, DisconnectReason.roomStopped);
      expect(event.closeCode, 1000);
      expect(event.closeReason, 'Room stopped');
    });

    test('errorEventFor only reports auth and join errors', () {
      expect(
        errorEventFor(const AuthClose(AuthErrorReason.expiredToken)),
        isA<AuthFailed>().having(
          (e) => e.reason,
          'reason',
          AuthErrorReason.expiredToken,
        ),
      );
      expect(
        errorEventFor(const JoinClose(JoinErrorReason.reachedPeersLimit)),
        isA<JoinFailed>().having(
          (e) => e.reason,
          'reason',
          JoinErrorReason.reachedPeersLimit,
        ),
      );
      expect(
        errorEventFor(const SessionEndedClose(SessionEndReason.peerRemoved)),
        isNull,
      );
      expect(errorEventFor(const ProtocolErrorClose()), isNull);
      expect(errorEventFor(const RetryableClose()), isNull);
    });

    test('connectExceptionFor maps to the connect() error', () {
      expect(
        connectExceptionFor(const AuthClose(AuthErrorReason.missingToken)),
        isA<AuthException>().having(
          (e) => e.reason,
          'reason',
          AuthErrorReason.missingToken,
        ),
      );
      expect(
        connectExceptionFor(const JoinClose(JoinErrorReason.invalidSdkVersion)),
        isA<JoinException>().having(
          (e) => e.reason,
          'reason',
          JoinErrorReason.invalidSdkVersion,
        ),
      );
      final error = StateError('lost');
      expect(
        connectExceptionFor(
          RetryableClose(code: 1006, reason: 'x', error: error),
        ),
        isA<ConnectionException>()
            .having((e) => e.code, 'code', 1006)
            .having((e) => e.reason, 'reason', 'x')
            .having((e) => e.cause, 'cause', error),
      );
      expect(
        connectExceptionFor(
          const SessionEndedClose(
            SessionEndReason.peerRemoved,
            code: 1000,
            reason: 'Peer removed',
          ),
        ),
        isA<ConnectionException>().having(
          (e) => e.reason,
          'reason',
          'Peer removed',
        ),
      );
    });
  });
}
