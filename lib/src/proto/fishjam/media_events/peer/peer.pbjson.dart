// This is a generated file - do not edit.
//
// Generated from fishjam/media_events/peer/peer.proto.

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

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent$json = {
  '1': 'MediaEvent',
  '2': [
    {
      '1': 'connect',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.Connect',
      '9': 0,
      '10': 'connect'
    },
    {
      '1': 'disconnect',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.Disconnect',
      '9': 0,
      '10': 'disconnect'
    },
    {
      '1': 'update_endpoint_metadata',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.UpdateEndpointMetadata',
      '9': 0,
      '10': 'updateEndpointMetadata'
    },
    {
      '1': 'update_track_metadata',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.UpdateTrackMetadata',
      '9': 0,
      '10': 'updateTrackMetadata'
    },
    {
      '1': 'renegotiate_tracks',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.RenegotiateTracks',
      '9': 0,
      '10': 'renegotiateTracks'
    },
    {
      '1': 'candidate',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.Candidate',
      '9': 0,
      '10': 'candidate'
    },
    {
      '1': 'sdp_offer',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.SdpOffer',
      '9': 0,
      '10': 'sdpOffer'
    },
    {
      '1': 'track_bitrates',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.TrackBitrates',
      '9': 0,
      '10': 'trackBitrates'
    },
    {
      '1': 'enable_track_variant',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.EnableTrackVariant',
      '9': 0,
      '10': 'enableTrackVariant'
    },
    {
      '1': 'disable_track_variant',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.DisableTrackVariant',
      '9': 0,
      '10': 'disableTrackVariant'
    },
    {
      '1': 'set_target_track_variant',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.SetTargetTrackVariant',
      '9': 0,
      '10': 'setTargetTrackVariant'
    },
    {
      '1': 'unmute_track',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.UnmuteTrack',
      '9': 0,
      '10': 'unmuteTrack'
    },
  ],
  '3': [
    MediaEvent_VariantBitrate$json,
    MediaEvent_Connect$json,
    MediaEvent_Disconnect$json,
    MediaEvent_UpdateEndpointMetadata$json,
    MediaEvent_UpdateTrackMetadata$json,
    MediaEvent_RenegotiateTracks$json,
    MediaEvent_SdpOffer$json,
    MediaEvent_TrackBitrates$json,
    MediaEvent_DisableTrackVariant$json,
    MediaEvent_EnableTrackVariant$json,
    MediaEvent_SetTargetTrackVariant$json,
    MediaEvent_UnmuteTrack$json
  ],
  '8': [
    {'1': 'content'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_VariantBitrate$json = {
  '1': 'VariantBitrate',
  '2': [
    {
      '1': 'variant',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'variant'
    },
    {'1': 'bitrate', '3': 2, '4': 1, '5': 5, '10': 'bitrate'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Connect$json = {
  '1': 'Connect',
  '2': [
    {'1': 'metadata_json', '3': 1, '4': 1, '5': 9, '10': 'metadataJson'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Disconnect$json = {
  '1': 'Disconnect',
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_UpdateEndpointMetadata$json = {
  '1': 'UpdateEndpointMetadata',
  '2': [
    {'1': 'metadata_json', '3': 1, '4': 1, '5': 9, '10': 'metadataJson'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_UpdateTrackMetadata$json = {
  '1': 'UpdateTrackMetadata',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 9, '10': 'trackId'},
    {'1': 'metadata_json', '3': 2, '4': 1, '5': 9, '10': 'metadataJson'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_RenegotiateTracks$json = {
  '1': 'RenegotiateTracks',
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_SdpOffer$json = {
  '1': 'SdpOffer',
  '2': [
    {'1': 'sdp', '3': 1, '4': 1, '5': 9, '10': 'sdp'},
    {
      '1': 'track_id_to_metadata_json',
      '3': 2,
      '4': 3,
      '5': 11,
      '6':
          '.fishjam.media_events.peer.MediaEvent.SdpOffer.TrackIdToMetadataJsonEntry',
      '10': 'trackIdToMetadataJson'
    },
    {
      '1': 'track_id_to_bitrates',
      '3': 3,
      '4': 3,
      '5': 11,
      '6':
          '.fishjam.media_events.peer.MediaEvent.SdpOffer.TrackIdToBitratesEntry',
      '10': 'trackIdToBitrates'
    },
    {
      '1': 'mid_to_track_id',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.SdpOffer.MidToTrackIdEntry',
      '10': 'midToTrackId'
    },
  ],
  '3': [
    MediaEvent_SdpOffer_TrackIdToMetadataJsonEntry$json,
    MediaEvent_SdpOffer_TrackIdToBitratesEntry$json,
    MediaEvent_SdpOffer_MidToTrackIdEntry$json
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_SdpOffer_TrackIdToMetadataJsonEntry$json = {
  '1': 'TrackIdToMetadataJsonEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_SdpOffer_TrackIdToBitratesEntry$json = {
  '1': 'TrackIdToBitratesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.TrackBitrates',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_SdpOffer_MidToTrackIdEntry$json = {
  '1': 'MidToTrackIdEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_TrackBitrates$json = {
  '1': 'TrackBitrates',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 9, '10': 'trackId'},
    {
      '1': 'variant_bitrates',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.fishjam.media_events.peer.MediaEvent.VariantBitrate',
      '10': 'variantBitrates'
    },
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_DisableTrackVariant$json = {
  '1': 'DisableTrackVariant',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 9, '10': 'trackId'},
    {
      '1': 'variant',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'variant'
    },
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_EnableTrackVariant$json = {
  '1': 'EnableTrackVariant',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 9, '10': 'trackId'},
    {
      '1': 'variant',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'variant'
    },
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_SetTargetTrackVariant$json = {
  '1': 'SetTargetTrackVariant',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 9, '10': 'trackId'},
    {
      '1': 'variant',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'variant'
    },
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_UnmuteTrack$json = {
  '1': 'UnmuteTrack',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 9, '10': 'trackId'},
  ],
};

/// Descriptor for `MediaEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaEventDescriptor = $convert.base64Decode(
    'CgpNZWRpYUV2ZW50EkkKB2Nvbm5lY3QYASABKAsyLS5maXNoamFtLm1lZGlhX2V2ZW50cy5wZW'
    'VyLk1lZGlhRXZlbnQuQ29ubmVjdEgAUgdjb25uZWN0ElIKCmRpc2Nvbm5lY3QYAiABKAsyMC5m'
    'aXNoamFtLm1lZGlhX2V2ZW50cy5wZWVyLk1lZGlhRXZlbnQuRGlzY29ubmVjdEgAUgpkaXNjb2'
    '5uZWN0EngKGHVwZGF0ZV9lbmRwb2ludF9tZXRhZGF0YRgDIAEoCzI8LmZpc2hqYW0ubWVkaWFf'
    'ZXZlbnRzLnBlZXIuTWVkaWFFdmVudC5VcGRhdGVFbmRwb2ludE1ldGFkYXRhSABSFnVwZGF0ZU'
    'VuZHBvaW50TWV0YWRhdGESbwoVdXBkYXRlX3RyYWNrX21ldGFkYXRhGAQgASgLMjkuZmlzaGph'
    'bS5tZWRpYV9ldmVudHMucGVlci5NZWRpYUV2ZW50LlVwZGF0ZVRyYWNrTWV0YWRhdGFIAFITdX'
    'BkYXRlVHJhY2tNZXRhZGF0YRJoChJyZW5lZ290aWF0ZV90cmFja3MYBSABKAsyNy5maXNoamFt'
    'Lm1lZGlhX2V2ZW50cy5wZWVyLk1lZGlhRXZlbnQuUmVuZWdvdGlhdGVUcmFja3NIAFIRcmVuZW'
    'dvdGlhdGVUcmFja3MSPwoJY2FuZGlkYXRlGAYgASgLMh8uZmlzaGphbS5tZWRpYV9ldmVudHMu'
    'Q2FuZGlkYXRlSABSCWNhbmRpZGF0ZRJNCglzZHBfb2ZmZXIYByABKAsyLi5maXNoamFtLm1lZG'
    'lhX2V2ZW50cy5wZWVyLk1lZGlhRXZlbnQuU2RwT2ZmZXJIAFIIc2RwT2ZmZXISXAoOdHJhY2tf'
    'Yml0cmF0ZXMYCCABKAsyMy5maXNoamFtLm1lZGlhX2V2ZW50cy5wZWVyLk1lZGlhRXZlbnQuVH'
    'JhY2tCaXRyYXRlc0gAUg10cmFja0JpdHJhdGVzEmwKFGVuYWJsZV90cmFja192YXJpYW50GAkg'
    'ASgLMjguZmlzaGphbS5tZWRpYV9ldmVudHMucGVlci5NZWRpYUV2ZW50LkVuYWJsZVRyYWNrVm'
    'FyaWFudEgAUhJlbmFibGVUcmFja1ZhcmlhbnQSbwoVZGlzYWJsZV90cmFja192YXJpYW50GAog'
    'ASgLMjkuZmlzaGphbS5tZWRpYV9ldmVudHMucGVlci5NZWRpYUV2ZW50LkRpc2FibGVUcmFja1'
    'ZhcmlhbnRIAFITZGlzYWJsZVRyYWNrVmFyaWFudBJ2ChhzZXRfdGFyZ2V0X3RyYWNrX3Zhcmlh'
    'bnQYCyABKAsyOy5maXNoamFtLm1lZGlhX2V2ZW50cy5wZWVyLk1lZGlhRXZlbnQuU2V0VGFyZ2'
    'V0VHJhY2tWYXJpYW50SABSFXNldFRhcmdldFRyYWNrVmFyaWFudBJWCgx1bm11dGVfdHJhY2sY'
    'DCABKAsyMS5maXNoamFtLm1lZGlhX2V2ZW50cy5wZWVyLk1lZGlhRXZlbnQuVW5tdXRlVHJhY2'
    'tIAFILdW5tdXRlVHJhY2saYwoOVmFyaWFudEJpdHJhdGUSNwoHdmFyaWFudBgBIAEoDjIdLmZp'
    'c2hqYW0ubWVkaWFfZXZlbnRzLlZhcmlhbnRSB3ZhcmlhbnQSGAoHYml0cmF0ZRgCIAEoBVIHYm'
    'l0cmF0ZRouCgdDb25uZWN0EiMKDW1ldGFkYXRhX2pzb24YASABKAlSDG1ldGFkYXRhSnNvbhoM'
    'CgpEaXNjb25uZWN0Gj0KFlVwZGF0ZUVuZHBvaW50TWV0YWRhdGESIwoNbWV0YWRhdGFfanNvbh'
    'gBIAEoCVIMbWV0YWRhdGFKc29uGlUKE1VwZGF0ZVRyYWNrTWV0YWRhdGESGQoIdHJhY2tfaWQY'
    'ASABKAlSB3RyYWNrSWQSIwoNbWV0YWRhdGFfanNvbhgCIAEoCVIMbWV0YWRhdGFKc29uGhMKEV'
    'JlbmVnb3RpYXRlVHJhY2tzGokFCghTZHBPZmZlchIQCgNzZHAYASABKAlSA3NkcBKDAQoZdHJh'
    'Y2tfaWRfdG9fbWV0YWRhdGFfanNvbhgCIAMoCzJJLmZpc2hqYW0ubWVkaWFfZXZlbnRzLnBlZX'
    'IuTWVkaWFFdmVudC5TZHBPZmZlci5UcmFja0lkVG9NZXRhZGF0YUpzb25FbnRyeVIVdHJhY2tJ'
    'ZFRvTWV0YWRhdGFKc29uEnYKFHRyYWNrX2lkX3RvX2JpdHJhdGVzGAMgAygLMkUuZmlzaGphbS'
    '5tZWRpYV9ldmVudHMucGVlci5NZWRpYUV2ZW50LlNkcE9mZmVyLlRyYWNrSWRUb0JpdHJhdGVz'
    'RW50cnlSEXRyYWNrSWRUb0JpdHJhdGVzEmcKD21pZF90b190cmFja19pZBgEIAMoCzJALmZpc2'
    'hqYW0ubWVkaWFfZXZlbnRzLnBlZXIuTWVkaWFFdmVudC5TZHBPZmZlci5NaWRUb1RyYWNrSWRF'
    'bnRyeVIMbWlkVG9UcmFja0lkGkgKGlRyYWNrSWRUb01ldGFkYXRhSnNvbkVudHJ5EhAKA2tleR'
    'gBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAEaeQoWVHJhY2tJZFRvQml0cmF0'
    'ZXNFbnRyeRIQCgNrZXkYASABKAlSA2tleRJJCgV2YWx1ZRgCIAEoCzIzLmZpc2hqYW0ubWVkaW'
    'FfZXZlbnRzLnBlZXIuTWVkaWFFdmVudC5UcmFja0JpdHJhdGVzUgV2YWx1ZToCOAEaPwoRTWlk'
    'VG9UcmFja0lkRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOg'
    'I4ARqLAQoNVHJhY2tCaXRyYXRlcxIZCgh0cmFja19pZBgBIAEoCVIHdHJhY2tJZBJfChB2YXJp'
    'YW50X2JpdHJhdGVzGAIgAygLMjQuZmlzaGphbS5tZWRpYV9ldmVudHMucGVlci5NZWRpYUV2ZW'
    '50LlZhcmlhbnRCaXRyYXRlUg92YXJpYW50Qml0cmF0ZXMaaQoTRGlzYWJsZVRyYWNrVmFyaWFu'
    'dBIZCgh0cmFja19pZBgBIAEoCVIHdHJhY2tJZBI3Cgd2YXJpYW50GAIgASgOMh0uZmlzaGphbS'
    '5tZWRpYV9ldmVudHMuVmFyaWFudFIHdmFyaWFudBpoChJFbmFibGVUcmFja1ZhcmlhbnQSGQoI'
    'dHJhY2tfaWQYASABKAlSB3RyYWNrSWQSNwoHdmFyaWFudBgCIAEoDjIdLmZpc2hqYW0ubWVkaW'
    'FfZXZlbnRzLlZhcmlhbnRSB3ZhcmlhbnQaawoVU2V0VGFyZ2V0VHJhY2tWYXJpYW50EhkKCHRy'
    'YWNrX2lkGAEgASgJUgd0cmFja0lkEjcKB3ZhcmlhbnQYAiABKA4yHS5maXNoamFtLm1lZGlhX2'
    'V2ZW50cy5WYXJpYW50Ugd2YXJpYW50GigKC1VubXV0ZVRyYWNrEhkKCHRyYWNrX2lkGAEgASgJ'
    'Ugd0cmFja0lkQgkKB2NvbnRlbnQ=');
