import 'package:fishjam_client/src/models/config.dart';
import 'package:fishjam_client/src/models/errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every terminal reason has its own DisconnectReason (SPEC §3.4, §4)',
    () {
      expect(DisconnectReason.values.map((r) => r.name), [
        'left',
        'peerRemoved',
        'roomStopped',
        'replacedByNewClient',
        'serverError',
        'authError',
        'joinError',
        'protocolError',
        'connectionLost',
        'reconnectionFailed',
      ]);
    },
  );

  test('session-ending close reasons map one to one', () {
    expect(SessionEndReason.values.map(DisconnectReason.fromSessionEnd), [
      DisconnectReason.peerRemoved,
      DisconnectReason.roomStopped,
      DisconnectReason.replacedByNewClient,
    ]);
  });
}
