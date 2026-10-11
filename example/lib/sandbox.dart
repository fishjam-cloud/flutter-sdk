import 'dart:convert';

import 'package:http/http.dart' as http;

/// Credentials for joining a room.
class RoomCredentials {
  const RoomCredentials({required this.url, required this.peerToken});

  /// Fishjam URL passed to `FishjamClient.connect`.
  final String url;

  /// Peer token passed to `FishjamClient.connect`.
  final String peerToken;
}

/// Gets a peer token for [peerName] in a conference room [roomName] from
/// the Sandbox API. Connect it to the Fishjam instance the Sandbox API URL
/// belongs to.
///
/// FOR PROTOTYPING ONLY. The Sandbox API is an unauthenticated test backend:
/// anyone who knows its URL can create rooms and peers. In production, your
/// own backend creates peers with a server SDK and hands the peer token to
/// the app.
Future<String> fetchSandboxPeerToken({
  required Uri sandboxApiUrl,
  required String roomName,
  required String peerName,
}) async {
  final url = sandboxApiUrl.replace(
    queryParameters: {
      ...sandboxApiUrl.queryParameters,
      'roomName': roomName,
      'peerName': peerName,
      'roomType': 'conference',
    },
  );
  final response = await http.get(url);
  if (response.statusCode == 409) {
    throw Exception(
      'Room "$roomName" already exists with a different room type or codec',
    );
  }
  if (response.statusCode != 200) {
    throw Exception(
      'Sandbox API returned ${response.statusCode} for room "$roomName"',
    );
  }
  final json = jsonDecode(response.body);
  final peerToken = json is Map<String, Object?> ? json['peerToken'] : null;
  if (peerToken is! String || peerToken.isEmpty) {
    throw Exception('Sandbox API response has no peer token');
  }
  return peerToken;
}
