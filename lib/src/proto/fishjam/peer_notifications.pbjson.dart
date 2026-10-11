// This is a generated file - do not edit.
//
// Generated from fishjam/peer_notifications.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use peerMessageDescriptor instead')
const PeerMessage$json = {
  '1': 'PeerMessage',
  '2': [
    {
      '1': 'authenticated',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.fishjam.PeerMessage.Authenticated',
      '9': 0,
      '10': 'authenticated'
    },
    {
      '1': 'auth_request',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.PeerMessage.AuthRequest',
      '9': 0,
      '10': 'authRequest'
    },
    {
      '1': 'media_event',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.fishjam.PeerMessage.MediaEvent',
      '9': 0,
      '10': 'mediaEvent'
    },
    {
      '1': 'rtc_stats_report',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.fishjam.PeerMessage.RTCStatsReport',
      '9': 0,
      '10': 'rtcStatsReport'
    },
    {
      '1': 'peer_media_event',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent',
      '9': 0,
      '10': 'peerMediaEvent'
    },
    {
      '1': 'server_media_event',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent',
      '9': 0,
      '10': 'serverMediaEvent'
    },
  ],
  '3': [
    PeerMessage_SdkDeprecation$json,
    PeerMessage_Authenticated$json,
    PeerMessage_AuthRequest$json,
    PeerMessage_RTCStatsReport$json,
    PeerMessage_MediaEvent$json
  ],
  '4': [PeerMessage_RoomType$json],
  '8': [
    {'1': 'content'},
  ],
};

@$core.Deprecated('Use peerMessageDescriptor instead')
const PeerMessage_SdkDeprecation$json = {
  '1': 'SdkDeprecation',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.fishjam.PeerMessage.SdkDeprecation.Status',
      '10': 'status'
    },
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
  '4': [PeerMessage_SdkDeprecation_Status$json],
};

@$core.Deprecated('Use peerMessageDescriptor instead')
const PeerMessage_SdkDeprecation_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'STATUS_UNSPECIFIED', '2': 0},
    {'1': 'STATUS_UP_TO_DATE', '2': 1},
    {'1': 'STATUS_DEPRECATED', '2': 2},
    {'1': 'STATUS_UNSUPPORTED', '2': 3},
  ],
};

@$core.Deprecated('Use peerMessageDescriptor instead')
const PeerMessage_Authenticated$json = {
  '1': 'Authenticated',
  '2': [
    {
      '1': 'room_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.fishjam.PeerMessage.RoomType',
      '10': 'roomType'
    },
    {
      '1': 'sdk_deprecation',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.PeerMessage.SdkDeprecation',
      '10': 'sdkDeprecation'
    },
  ],
};

@$core.Deprecated('Use peerMessageDescriptor instead')
const PeerMessage_AuthRequest$json = {
  '1': 'AuthRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'sdk_version', '3': 2, '4': 1, '5': 9, '10': 'sdkVersion'},
  ],
};

@$core.Deprecated('Use peerMessageDescriptor instead')
const PeerMessage_RTCStatsReport$json = {
  '1': 'RTCStatsReport',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 9, '10': 'data'},
  ],
};

@$core.Deprecated('Use peerMessageDescriptor instead')
const PeerMessage_MediaEvent$json = {
  '1': 'MediaEvent',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 9, '10': 'data'},
  ],
};

@$core.Deprecated('Use peerMessageDescriptor instead')
const PeerMessage_RoomType$json = {
  '1': 'RoomType',
  '2': [
    {'1': 'ROOM_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ROOM_TYPE_CONFERENCE', '2': 1},
    {'1': 'ROOM_TYPE_AUDIO_ONLY', '2': 2},
    {'1': 'ROOM_TYPE_LIVESTREAM', '2': 3},
  ],
};

/// Descriptor for `PeerMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerMessageDescriptor = $convert.base64Decode(
    'CgtQZWVyTWVzc2FnZRJKCg1hdXRoZW50aWNhdGVkGAEgASgLMiIuZmlzaGphbS5QZWVyTWVzc2'
    'FnZS5BdXRoZW50aWNhdGVkSABSDWF1dGhlbnRpY2F0ZWQSRQoMYXV0aF9yZXF1ZXN0GAIgASgL'
    'MiAuZmlzaGphbS5QZWVyTWVzc2FnZS5BdXRoUmVxdWVzdEgAUgthdXRoUmVxdWVzdBJCCgttZW'
    'RpYV9ldmVudBgDIAEoCzIfLmZpc2hqYW0uUGVlck1lc3NhZ2UuTWVkaWFFdmVudEgAUgptZWRp'
    'YUV2ZW50Ek8KEHJ0Y19zdGF0c19yZXBvcnQYBCABKAsyIy5maXNoamFtLlBlZXJNZXNzYWdlLl'
    'JUQ1N0YXRzUmVwb3J0SABSDnJ0Y1N0YXRzUmVwb3J0ElEKEHBlZXJfbWVkaWFfZXZlbnQYBSAB'
    'KAsyJS5maXNoamFtLm1lZGlhX2V2ZW50cy5wZWVyLk1lZGlhRXZlbnRIAFIOcGVlck1lZGlhRX'
    'ZlbnQSVwoSc2VydmVyX21lZGlhX2V2ZW50GAYgASgLMicuZmlzaGphbS5tZWRpYV9ldmVudHMu'
    'c2VydmVyLk1lZGlhRXZlbnRIAFIQc2VydmVyTWVkaWFFdmVudBrWAQoOU2RrRGVwcmVjYXRpb2'
    '4SQgoGc3RhdHVzGAEgASgOMiouZmlzaGphbS5QZWVyTWVzc2FnZS5TZGtEZXByZWNhdGlvbi5T'
    'dGF0dXNSBnN0YXR1cxIYCgdtZXNzYWdlGAIgASgJUgdtZXNzYWdlImYKBlN0YXR1cxIWChJTVE'
    'FUVVNfVU5TUEVDSUZJRUQQABIVChFTVEFUVVNfVVBfVE9fREFURRABEhUKEVNUQVRVU19ERVBS'
    'RUNBVEVEEAISFgoSU1RBVFVTX1VOU1VQUE9SVEVEEAMamQEKDUF1dGhlbnRpY2F0ZWQSOgoJcm'
    '9vbV90eXBlGAEgASgOMh0uZmlzaGphbS5QZWVyTWVzc2FnZS5Sb29tVHlwZVIIcm9vbVR5cGUS'
    'TAoPc2RrX2RlcHJlY2F0aW9uGAIgASgLMiMuZmlzaGphbS5QZWVyTWVzc2FnZS5TZGtEZXByZW'
    'NhdGlvblIOc2RrRGVwcmVjYXRpb24aRAoLQXV0aFJlcXVlc3QSFAoFdG9rZW4YASABKAlSBXRv'
    'a2VuEh8KC3Nka192ZXJzaW9uGAIgASgJUgpzZGtWZXJzaW9uGiQKDlJUQ1N0YXRzUmVwb3J0Eh'
    'IKBGRhdGEYASABKAlSBGRhdGEaIAoKTWVkaWFFdmVudBISCgRkYXRhGAEgASgJUgRkYXRhInMK'
    'CFJvb21UeXBlEhkKFVJPT01fVFlQRV9VTlNQRUNJRklFRBAAEhgKFFJPT01fVFlQRV9DT05GRV'
    'JFTkNFEAESGAoUUk9PTV9UWVBFX0FVRElPX09OTFkQAhIYChRST09NX1RZUEVfTElWRVNUUkVB'
    'TRADQgkKB2NvbnRlbnQ=');
