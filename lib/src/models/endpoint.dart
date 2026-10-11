/// Public endpoint models: peers and components (SPEC §14.1). Owner: Architect.
library;

import 'package:collection/collection.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:meta/meta.dart';

/// Endpoint metadata as reported by the server.
@immutable
final class Metadata {
  /// Creates metadata.
  const Metadata({this.peer, this.server});

  /// Builds metadata from a decoded server value (SPEC §2.3): an object
  /// `{"peer": …, "server": …}` is split, anything else becomes [peer].
  factory Metadata.fromServerJson(Object? json) {
    if (json is Map<String, Object?> &&
        json.length <= 2 &&
        json.keys.every((k) => k == 'peer' || k == 'server')) {
      return Metadata(peer: json['peer'], server: json['server']);
    }
    return Metadata(peer: json);
  }

  /// Metadata set by the peer itself (on connect or update).
  final Object? peer;

  /// Metadata set by the app's backend when creating the peer.
  final Object? server;

  @override
  bool operator ==(Object other) =>
      other is Metadata &&
      _equality.equals(other.peer, peer) &&
      _equality.equals(other.server, server);

  @override
  int get hashCode => Object.hash(_equality.hash(peer), _equality.hash(server));

  static const _equality = DeepCollectionEquality();

  @override
  String toString() => 'Metadata(peer: $peer, server: $server)';
}

/// Endpoint types reported for peers (clients like this one).
const peerEndpointTypes = {'webrtc', 'exwebrtc'};

/// Endpoint types reported for components.
const componentEndpointTypes = {'recording', 'hls', 'file', 'rtsp', 'sip'};

/// Another client in the room.
@immutable
final class Peer {
  /// Creates a peer snapshot.
  const Peer({
    required this.id,
    required this.type,
    required this.metadata,
    this.tracks = const {},
  });

  /// Peer id.
  final String id;

  /// Endpoint type as reported by the server.
  final String type;

  /// Peer metadata.
  final Metadata metadata;

  /// Tracks published by the peer, by track id.
  final Map<String, RemoteTrackContext> tracks;

  @override
  String toString() => 'Peer($id, ${tracks.length} tracks)';
}

/// A server-side media producer in the room (recording, stream ingest, …).
@immutable
final class Component {
  /// Creates a component snapshot.
  const Component({
    required this.id,
    required this.type,
    required this.metadata,
    this.tracks = const {},
  });

  /// Component id.
  final String id;

  /// One of [componentEndpointTypes].
  final String type;

  /// Component metadata.
  final Metadata metadata;

  /// Tracks published by the component, by track id.
  final Map<String, RemoteTrackContext> tracks;

  @override
  String toString() => 'Component($id, $type)';
}

/// This client as a member of the room.
@immutable
final class LocalPeer {
  /// Creates a local peer snapshot.
  const LocalPeer({
    required this.id,
    required this.metadata,
    this.tracks = const {},
  });

  /// Peer id assigned by the server.
  final String id;

  /// Metadata as last reported by the server (or set locally).
  final Metadata metadata;

  /// Tracks published by this client, by track id.
  final Map<String, LocalTrackContext> tracks;

  @override
  String toString() => 'LocalPeer($id, ${tracks.length} tracks)';
}
