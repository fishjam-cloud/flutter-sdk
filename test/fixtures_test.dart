import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

/// Public API names fixtures may call (FishjamClient methods).
const _apiCalls = {
  'connect',
  'leave',
  'addTrack',
  'removeTrack',
  'replaceTrack',
  'setTrackBandwidth',
  'setEncodingBandwidth',
  'enableTrackEncoding',
  'disableTrackEncoding',
  'setTargetTrackEncoding',
  'updatePeerMetadata',
  'updateTrackMetadata',
  'createDataChannels',
  'publishData',
};

const _rtcEvents = {
  'iceConnectionState',
  'connectionState',
  'iceGatheringState',
  'onTrack',
  'iceCandidate',
  'dataChannelState',
  'dataChannelMessage',
};

const _rtcCalls = {
  'addTransceiver',
  'stopTransceiver',
  'removeTrack',
  'createOffer',
  'setLocalDescription',
  'setRemoteDescription',
  'addIceCandidate',
  'createDataChannel',
  'dataChannelSend',
  'setParameters',
  'replaceTrack',
  'close',
};

/// Every scenario the spec requires a golden sequence for.
const _required = {
  'join_empty_room',
  'join_room_with_peers',
  'publish_one_track',
  'publish_three_tracks_batched',
  'simulcast_publish',
  'remote_track_lifecycle',
  'peer_joined_updated_left',
  'metadata_updates',
  'renegotiate_on_ice_disconnected',
  'server_error_event',
  'auth_failure_close',
  'join_failure_close',
  'reconnect_with_track_restore',
  'data_channels',
  'session_ended_close',
};

final _placeholder = RegExp(r'\$\{(\w+)\}');

/// Binds every placeholder in [json] to a dummy value so it can be parsed.
Object? _dummy(Object? json) {
  if (json is String) {
    return json.replaceAllMapped(_placeholder, (m) => 'dummy-${m[1]}');
  }
  if (json is Map<String, Object?>) {
    return {
      for (final e in json.entries) _dummy(e.key)! as String: _dummy(e.value),
    };
  }
  if (json is List<Object?>) return json.map(_dummy).toList();
  return json;
}

void main() {
  test('every required fixture exists', () {
    expect(Fixture.all().toSet(), containsAll(_required));
  });

  for (final name in Fixture.all()) {
    group(name, () {
      late Fixture fixture;

      setUp(() => fixture = Fixture.load(name));

      test('name matches the file and it has a description', () {
        expect(fixture.name, name);
        expect(fixture.description, isNotEmpty);
        expect(fixture.steps, isNotEmpty);
      });

      test('every message is a valid PeerMessage in proto3 JSON', () {
        for (final step in fixture.steps) {
          final message = switch (step) {
            InStep(:final message) || OutStep(:final message) => message,
            _ => null,
          };
          if (message == null) continue;
          final parsed = PeerMessage()..mergeFromProto3Json(_dummy(message));
          expect(
            parsed.whichContent(),
            isNot(PeerMessage_Content.notSet),
            reason: 'step ${step.index}',
          );
        }
      });

      test('steps use known APIs, events and WebRTC calls', () {
        for (final step in fixture.steps) {
          switch (step) {
            case ApiStep(:final call):
              expect(_apiCalls, contains(call), reason: 'step ${step.index}');
            case RtcStep(:final event):
              expect(_rtcEvents, contains(event), reason: 'step ${step.index}');
            case ExpectRtcStep(:final call):
              expect(_rtcCalls, contains(call), reason: 'step ${step.index}');
            case ExpectEventStep(:final event):
              expect(
                knownEventNames,
                contains(event),
                reason: 'step ${step.index}',
              );
            case InStep() ||
                OutStep() ||
                CloseStep() ||
                WaitStep() ||
                NoOutStep():
              break;
          }
        }
      });

      test('server messages only use names bound earlier', () {
        final bound = <String>{};
        for (final step in fixture.steps) {
          final json = switch (step) {
            OutStep(:final message) => message,
            ExpectRtcStep(:final args) => args,
            ExpectEventStep(:final fields) => fields,
            ApiStep(:final bind) => bind == null ? null : '\${$bind}',
            _ => null,
          };
          if (json != null) {
            bound.addAll(_placeholder.allMatches('$json').map((m) => m[1]!));
          }
          final consumed = switch (step) {
            InStep(:final message) => message,
            ApiStep(:final args) => args,
            RtcStep(:final args) => args,
            _ => null,
          };
          if (consumed == null) continue;
          for (final m in _placeholder.allMatches('$consumed')) {
            expect(
              bound,
              contains(m[1]),
              reason: 'step ${step.index} uses \${${m[1]}} before binding it',
            );
          }
        }
      });
    });
  }
}
