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

/// Gets a peer token from the Sandbox API.
///
/// FOR PROTOTYPING ONLY. The Sandbox API is an unauthenticated test backend:
/// anyone who knows its URL can create rooms and peers. In production, your
/// own backend creates peers with a server SDK and hands the peer token to
/// the app.
Future<RoomCredentials> fetchSandboxCredentials({
  required Uri sandboxApiUrl,
  required String roomName,
  required String peerName,
}) async {
  final url = sandboxApiUrl.replace(
    queryParameters: {
      ...sandboxApiUrl.queryParameters,
      'roomName': roomName,
      'peerName': peerName,
    },
  );
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception(
      'Sandbox API returned ${response.statusCode} for room "$roomName"',
    );
  }
  final json = jsonDecode(response.body) as Map<String, Object?>;
  return RoomCredentials(
    url: json['url']! as String,
    peerToken: json['peerToken']! as String,
  );
}
