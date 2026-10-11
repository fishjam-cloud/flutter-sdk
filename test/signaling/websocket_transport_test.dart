import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/signaling/transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// A local WebSocket server; [onSocket] receives each server-side socket.
Future<(HttpServer, Uri)> _serve(
  void Function(WebSocket socket) onSocket,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    onSocket(await WebSocketTransformer.upgrade(request));
  });
  return (server, Uri.parse('ws://127.0.0.1:${server.port}/socket'));
}

void main() {
  test('exchanges binary frames and drops text frames', () async {
    final serverSide = Completer<WebSocket>();
    final received = <Object?>[];
    final (server, url) = await _serve((socket) {
      socket.listen(received.add);
      serverSide.complete(socket);
    });
    addTearDown(server.close);
    final logs = <String>[];
    final transport = WebSocketTransport(
      logger: FishjamLogger(
        enabled: true,
        sink: (level, message, {error, stackTrace}) => logs.add(message),
      ),
    );

    await transport.connect(url);
    expect(transport.isOpen, isTrue);
    final incoming = <Uint8List>[];
    transport.incoming.listen(incoming.add);
    transport.send(Uint8List.fromList([1, 2, 3]));
    final socket = await serverSide.future;
    socket
      ..add('text is ignored')
      ..add(Uint8List.fromList([4, 5]));

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(received.single, [1, 2, 3]);
    expect(incoming.single, [4, 5]);
    expect(logs.single, contains('text frame'));
    await transport.close();
  });

  test('reports the server close code and reason', () async {
    final (server, url) = await _serve((socket) {
      unawaited(socket.close(1000, 'Invalid token'));
    });
    addTearDown(server.close);
    final transport = WebSocketTransport();

    await transport.connect(url);

    expect(
      await transport.onClose,
      const TransportClosed(code: 1000, reason: 'Invalid token'),
    );
    expect(transport.isOpen, isFalse);
  });

  test('client close completes onClose with its code', () async {
    final (server, url) = await _serve((socket) => socket.listen(null));
    addTearDown(server.close);
    final transport = WebSocketTransport();
    await transport.connect(url);

    await transport.close(1000, 'bye');

    expect((await transport.onClose).code, 1000);
    transport.send(Uint8List.fromList([1]));
  });

  test('closing before connecting completes onClose', () async {
    final transport = WebSocketTransport();

    await transport.close();

    expect((await transport.onClose).code, 1000);
  });

  test('connect failure throws and completes onClose with the error', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);
    final transport = WebSocketTransport();

    await expectLater(
      transport.connect(Uri.parse('ws://127.0.0.1:$port/socket')),
      throwsA(
        isA<TransportException>().having(
          (e) => e.toString(),
          'toString',
          contains('Cannot connect'),
        ),
      ),
    );
    expect((await transport.onClose).error, isNotNull);
  });

  test('a transport is single use', () async {
    final (server, url) = await _serve((socket) => socket.listen(null));
    addTearDown(server.close);
    final transport = WebSocketTransport();
    await transport.connect(url);

    await expectLater(transport.connect(url), throwsStateError);
    await transport.close();
  });

  test('TransportClosed and TransportException describe themselves', () {
    expect(
      const TransportClosed(code: 1, reason: 'r').toString(),
      contains('code: 1'),
    );
    expect(const TransportClosed().hashCode, const TransportClosed().hashCode);
    expect(const TransportException('m').toString(), 'TransportException: m');
  });
}
