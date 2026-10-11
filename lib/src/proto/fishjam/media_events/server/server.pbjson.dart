// This is a generated file - do not edit.
//
// Generated from fishjam/media_events/server/server.proto.

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
      '1': 'endpoint_updated',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.EndpointUpdated',
      '9': 0,
      '10': 'endpointUpdated'
    },
    {
      '1': 'track_updated',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.TrackUpdated',
      '9': 0,
      '10': 'trackUpdated'
    },
    {
      '1': 'tracks_added',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.TracksAdded',
      '9': 0,
      '10': 'tracksAdded'
    },
    {
      '1': 'tracks_removed',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.TracksRemoved',
      '9': 0,
      '10': 'tracksRemoved'
    },
    {
      '1': 'endpoint_added',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.EndpointAdded',
      '9': 0,
      '10': 'endpointAdded'
    },
    {
      '1': 'endpoint_removed',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.EndpointRemoved',
      '9': 0,
      '10': 'endpointRemoved'
    },
    {
      '1': 'connected',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.Connected',
      '9': 0,
      '10': 'connected'
    },
    {
      '1': 'error',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.Error',
      '9': 0,
      '10': 'error'
    },
    {
      '1': 'offer_data',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.OfferData',
      '9': 0,
      '10': 'offerData'
    },
    {
      '1': 'candidate',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.Candidate',
      '9': 0,
      '10': 'candidate'
    },
    {
      '1': 'sdp_answer',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.SdpAnswer',
      '9': 0,
      '10': 'sdpAnswer'
    },
    {
      '1': 'vad_notification',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.VadNotification',
      '9': 0,
      '10': 'vadNotification'
    },
    {
      '1': 'track_variant_switched',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.TrackVariantSwitched',
      '9': 0,
      '10': 'trackVariantSwitched'
    },
    {
      '1': 'track_variant_disabled',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.TrackVariantDisabled',
      '9': 0,
      '10': 'trackVariantDisabled'
    },
    {
      '1': 'track_variant_enabled',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.TrackVariantEnabled',
      '9': 0,
      '10': 'trackVariantEnabled'
    },
  ],
  '3': [
    MediaEvent_Track$json,
    MediaEvent_Endpoint$json,
    MediaEvent_IceServer$json,
    MediaEvent_EndpointUpdated$json,
    MediaEvent_TrackUpdated$json,
    MediaEvent_TracksAdded$json,
    MediaEvent_TracksRemoved$json,
    MediaEvent_EndpointAdded$json,
    MediaEvent_Connected$json,
    MediaEvent_EndpointRemoved$json,
    MediaEvent_Error$json,
    MediaEvent_OfferData$json,
    MediaEvent_SdpAnswer$json,
    MediaEvent_VadNotification$json,
    MediaEvent_TrackVariantSwitched$json,
    MediaEvent_TrackVariantDisabled$json,
    MediaEvent_TrackVariantEnabled$json
  ],
  '8': [
    {'1': 'content'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Track$json = {
  '1': 'Track',
  '2': [
    {'1': 'metadata_json', '3': 1, '4': 1, '5': 9, '10': 'metadataJson'},
    {
      '1': 'simulcast_config',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.Track.SimulcastConfig',
      '10': 'simulcastConfig'
    },
  ],
  '3': [MediaEvent_Track_SimulcastConfig$json],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Track_SimulcastConfig$json = {
  '1': 'SimulcastConfig',
  '2': [
    {'1': 'enabled', '3': 1, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'enabled_variants',
      '3': 2,
      '4': 3,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'enabledVariants'
    },
    {
      '1': 'disabled_variants',
      '3': 3,
      '4': 3,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'disabledVariants'
    },
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Endpoint$json = {
  '1': 'Endpoint',
  '2': [
    {'1': 'endpoint_type', '3': 2, '4': 1, '5': 9, '10': 'endpointType'},
    {'1': 'metadata_json', '3': 3, '4': 1, '5': 9, '10': 'metadataJson'},
    {
      '1': 'track_id_to_track',
      '3': 4,
      '4': 3,
      '5': 11,
      '6':
          '.fishjam.media_events.server.MediaEvent.Endpoint.TrackIdToTrackEntry',
      '10': 'trackIdToTrack'
    },
  ],
  '3': [MediaEvent_Endpoint_TrackIdToTrackEntry$json],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Endpoint_TrackIdToTrackEntry$json = {
  '1': 'TrackIdToTrackEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.Track',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_IceServer$json = {
  '1': 'IceServer',
  '2': [
    {'1': 'credential', '3': 1, '4': 1, '5': 9, '10': 'credential'},
    {'1': 'urls', '3': 2, '4': 3, '5': 9, '10': 'urls'},
    {'1': 'username', '3': 3, '4': 1, '5': 9, '10': 'username'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_EndpointUpdated$json = {
  '1': 'EndpointUpdated',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {'1': 'metadata_json', '3': 2, '4': 1, '5': 9, '10': 'metadataJson'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_TrackUpdated$json = {
  '1': 'TrackUpdated',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {'1': 'track_id', '3': 2, '4': 1, '5': 9, '10': 'trackId'},
    {'1': 'metadata_json', '3': 3, '4': 1, '5': 9, '10': 'metadataJson'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_TracksAdded$json = {
  '1': 'TracksAdded',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {
      '1': 'track_id_to_track',
      '3': 2,
      '4': 3,
      '5': 11,
      '6':
          '.fishjam.media_events.server.MediaEvent.TracksAdded.TrackIdToTrackEntry',
      '10': 'trackIdToTrack'
    },
  ],
  '3': [MediaEvent_TracksAdded_TrackIdToTrackEntry$json],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_TracksAdded_TrackIdToTrackEntry$json = {
  '1': 'TrackIdToTrackEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.Track',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_TracksRemoved$json = {
  '1': 'TracksRemoved',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {'1': 'track_ids', '3': 2, '4': 3, '5': 9, '10': 'trackIds'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_EndpointAdded$json = {
  '1': 'EndpointAdded',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {'1': 'metadata_json', '3': 2, '4': 1, '5': 9, '10': 'metadataJson'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Connected$json = {
  '1': 'Connected',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {
      '1': 'endpoint_id_to_endpoint',
      '3': 2,
      '4': 3,
      '5': 11,
      '6':
          '.fishjam.media_events.server.MediaEvent.Connected.EndpointIdToEndpointEntry',
      '10': 'endpointIdToEndpoint'
    },
    {
      '1': 'ice_servers',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.IceServer',
      '10': 'iceServers'
    },
  ],
  '3': [MediaEvent_Connected_EndpointIdToEndpointEntry$json],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Connected_EndpointIdToEndpointEntry$json = {
  '1': 'EndpointIdToEndpointEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.Endpoint',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_EndpointRemoved$json = {
  '1': 'EndpointRemoved',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_Error$json = {
  '1': 'Error',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_OfferData$json = {
  '1': 'OfferData',
  '2': [
    {
      '1': 'tracks_types',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.server.MediaEvent.OfferData.TrackTypes',
      '10': 'tracksTypes'
    },
  ],
  '3': [MediaEvent_OfferData_TrackTypes$json],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_OfferData_TrackTypes$json = {
  '1': 'TrackTypes',
  '2': [
    {'1': 'audio', '3': 1, '4': 1, '5': 5, '10': 'audio'},
    {'1': 'video', '3': 2, '4': 1, '5': 5, '10': 'video'},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_SdpAnswer$json = {
  '1': 'SdpAnswer',
  '2': [
    {'1': 'sdp', '3': 1, '4': 1, '5': 9, '10': 'sdp'},
    {
      '1': 'mid_to_track_id',
      '3': 2,
      '4': 3,
      '5': 11,
      '6':
          '.fishjam.media_events.server.MediaEvent.SdpAnswer.MidToTrackIdEntry',
      '10': 'midToTrackId'
    },
  ],
  '3': [MediaEvent_SdpAnswer_MidToTrackIdEntry$json],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_SdpAnswer_MidToTrackIdEntry$json = {
  '1': 'MidToTrackIdEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_VadNotification$json = {
  '1': 'VadNotification',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 9, '10': 'trackId'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.fishjam.media_events.server.MediaEvent.VadNotification.Status',
      '10': 'status'
    },
  ],
  '4': [MediaEvent_VadNotification_Status$json],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_VadNotification_Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'STATUS_UNSPECIFIED', '2': 0},
    {'1': 'STATUS_SILENCE', '2': 1},
    {'1': 'STATUS_SPEECH', '2': 2},
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_TrackVariantSwitched$json = {
  '1': 'TrackVariantSwitched',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {'1': 'track_id', '3': 2, '4': 1, '5': 9, '10': 'trackId'},
    {
      '1': 'variant',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'variant'
    },
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_TrackVariantDisabled$json = {
  '1': 'TrackVariantDisabled',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {'1': 'track_id', '3': 2, '4': 1, '5': 9, '10': 'trackId'},
    {
      '1': 'variant',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'variant'
    },
  ],
};

@$core.Deprecated('Use mediaEventDescriptor instead')
const MediaEvent_TrackVariantEnabled$json = {
  '1': 'TrackVariantEnabled',
  '2': [
    {'1': 'endpoint_id', '3': 1, '4': 1, '5': 9, '10': 'endpointId'},
    {'1': 'track_id', '3': 2, '4': 1, '5': 9, '10': 'trackId'},
    {
      '1': 'variant',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.fishjam.media_events.Variant',
      '10': 'variant'
    },
  ],
};

/// Descriptor for `MediaEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaEventDescriptor = $convert.base64Decode(
    'CgpNZWRpYUV2ZW50EmQKEGVuZHBvaW50X3VwZGF0ZWQYASABKAsyNy5maXNoamFtLm1lZGlhX2'
    'V2ZW50cy5zZXJ2ZXIuTWVkaWFFdmVudC5FbmRwb2ludFVwZGF0ZWRIAFIPZW5kcG9pbnRVcGRh'
    'dGVkElsKDXRyYWNrX3VwZGF0ZWQYAiABKAsyNC5maXNoamFtLm1lZGlhX2V2ZW50cy5zZXJ2ZX'
    'IuTWVkaWFFdmVudC5UcmFja1VwZGF0ZWRIAFIMdHJhY2tVcGRhdGVkElgKDHRyYWNrc19hZGRl'
    'ZBgDIAEoCzIzLmZpc2hqYW0ubWVkaWFfZXZlbnRzLnNlcnZlci5NZWRpYUV2ZW50LlRyYWNrc0'
    'FkZGVkSABSC3RyYWNrc0FkZGVkEl4KDnRyYWNrc19yZW1vdmVkGAQgASgLMjUuZmlzaGphbS5t'
    'ZWRpYV9ldmVudHMuc2VydmVyLk1lZGlhRXZlbnQuVHJhY2tzUmVtb3ZlZEgAUg10cmFja3NSZW'
    '1vdmVkEl4KDmVuZHBvaW50X2FkZGVkGAUgASgLMjUuZmlzaGphbS5tZWRpYV9ldmVudHMuc2Vy'
    'dmVyLk1lZGlhRXZlbnQuRW5kcG9pbnRBZGRlZEgAUg1lbmRwb2ludEFkZGVkEmQKEGVuZHBvaW'
    '50X3JlbW92ZWQYBiABKAsyNy5maXNoamFtLm1lZGlhX2V2ZW50cy5zZXJ2ZXIuTWVkaWFFdmVu'
    'dC5FbmRwb2ludFJlbW92ZWRIAFIPZW5kcG9pbnRSZW1vdmVkElEKCWNvbm5lY3RlZBgHIAEoCz'
    'IxLmZpc2hqYW0ubWVkaWFfZXZlbnRzLnNlcnZlci5NZWRpYUV2ZW50LkNvbm5lY3RlZEgAUglj'
    'b25uZWN0ZWQSRQoFZXJyb3IYCCABKAsyLS5maXNoamFtLm1lZGlhX2V2ZW50cy5zZXJ2ZXIuTW'
    'VkaWFFdmVudC5FcnJvckgAUgVlcnJvchJSCgpvZmZlcl9kYXRhGAkgASgLMjEuZmlzaGphbS5t'
    'ZWRpYV9ldmVudHMuc2VydmVyLk1lZGlhRXZlbnQuT2ZmZXJEYXRhSABSCW9mZmVyRGF0YRI/Cg'
    'ljYW5kaWRhdGUYCiABKAsyHy5maXNoamFtLm1lZGlhX2V2ZW50cy5DYW5kaWRhdGVIAFIJY2Fu'
    'ZGlkYXRlElIKCnNkcF9hbnN3ZXIYCyABKAsyMS5maXNoamFtLm1lZGlhX2V2ZW50cy5zZXJ2ZX'
    'IuTWVkaWFFdmVudC5TZHBBbnN3ZXJIAFIJc2RwQW5zd2VyEmQKEHZhZF9ub3RpZmljYXRpb24Y'
    'DCABKAsyNy5maXNoamFtLm1lZGlhX2V2ZW50cy5zZXJ2ZXIuTWVkaWFFdmVudC5WYWROb3RpZm'
    'ljYXRpb25IAFIPdmFkTm90aWZpY2F0aW9uEnQKFnRyYWNrX3ZhcmlhbnRfc3dpdGNoZWQYDSAB'
    'KAsyPC5maXNoamFtLm1lZGlhX2V2ZW50cy5zZXJ2ZXIuTWVkaWFFdmVudC5UcmFja1Zhcmlhbn'
    'RTd2l0Y2hlZEgAUhR0cmFja1ZhcmlhbnRTd2l0Y2hlZBJ0ChZ0cmFja192YXJpYW50X2Rpc2Fi'
    'bGVkGA4gASgLMjwuZmlzaGphbS5tZWRpYV9ldmVudHMuc2VydmVyLk1lZGlhRXZlbnQuVHJhY2'
    'tWYXJpYW50RGlzYWJsZWRIAFIUdHJhY2tWYXJpYW50RGlzYWJsZWQScQoVdHJhY2tfdmFyaWFu'
    'dF9lbmFibGVkGA8gASgLMjsuZmlzaGphbS5tZWRpYV9ldmVudHMuc2VydmVyLk1lZGlhRXZlbn'
    'QuVHJhY2tWYXJpYW50RW5hYmxlZEgAUhN0cmFja1ZhcmlhbnRFbmFibGVkGtoCCgVUcmFjaxIj'
    'Cg1tZXRhZGF0YV9qc29uGAEgASgJUgxtZXRhZGF0YUpzb24SaAoQc2ltdWxjYXN0X2NvbmZpZx'
    'gCIAEoCzI9LmZpc2hqYW0ubWVkaWFfZXZlbnRzLnNlcnZlci5NZWRpYUV2ZW50LlRyYWNrLlNp'
    'bXVsY2FzdENvbmZpZ1IPc2ltdWxjYXN0Q29uZmlnGsEBCg9TaW11bGNhc3RDb25maWcSGAoHZW'
    '5hYmxlZBgBIAEoCFIHZW5hYmxlZBJIChBlbmFibGVkX3ZhcmlhbnRzGAIgAygOMh0uZmlzaGph'
    'bS5tZWRpYV9ldmVudHMuVmFyaWFudFIPZW5hYmxlZFZhcmlhbnRzEkoKEWRpc2FibGVkX3Zhcm'
    'lhbnRzGAMgAygOMh0uZmlzaGphbS5tZWRpYV9ldmVudHMuVmFyaWFudFIQZGlzYWJsZWRWYXJp'
    'YW50cxq3AgoIRW5kcG9pbnQSIwoNZW5kcG9pbnRfdHlwZRgCIAEoCVIMZW5kcG9pbnRUeXBlEi'
    'MKDW1ldGFkYXRhX2pzb24YAyABKAlSDG1ldGFkYXRhSnNvbhJvChF0cmFja19pZF90b190cmFj'
    'axgEIAMoCzJELmZpc2hqYW0ubWVkaWFfZXZlbnRzLnNlcnZlci5NZWRpYUV2ZW50LkVuZHBvaW'
    '50LlRyYWNrSWRUb1RyYWNrRW50cnlSDnRyYWNrSWRUb1RyYWNrGnAKE1RyYWNrSWRUb1RyYWNr'
    'RW50cnkSEAoDa2V5GAEgASgJUgNrZXkSQwoFdmFsdWUYAiABKAsyLS5maXNoamFtLm1lZGlhX2'
    'V2ZW50cy5zZXJ2ZXIuTWVkaWFFdmVudC5UcmFja1IFdmFsdWU6AjgBGlsKCUljZVNlcnZlchIe'
    'CgpjcmVkZW50aWFsGAEgASgJUgpjcmVkZW50aWFsEhIKBHVybHMYAiADKAlSBHVybHMSGgoIdX'
    'Nlcm5hbWUYAyABKAlSCHVzZXJuYW1lGlcKD0VuZHBvaW50VXBkYXRlZBIfCgtlbmRwb2ludF9p'
    'ZBgBIAEoCVIKZW5kcG9pbnRJZBIjCg1tZXRhZGF0YV9qc29uGAIgASgJUgxtZXRhZGF0YUpzb2'
    '4abwoMVHJhY2tVcGRhdGVkEh8KC2VuZHBvaW50X2lkGAEgASgJUgplbmRwb2ludElkEhkKCHRy'
    'YWNrX2lkGAIgASgJUgd0cmFja0lkEiMKDW1ldGFkYXRhX2pzb24YAyABKAlSDG1ldGFkYXRhSn'
    'NvbhqUAgoLVHJhY2tzQWRkZWQSHwoLZW5kcG9pbnRfaWQYASABKAlSCmVuZHBvaW50SWQScgoR'
    'dHJhY2tfaWRfdG9fdHJhY2sYAiADKAsyRy5maXNoamFtLm1lZGlhX2V2ZW50cy5zZXJ2ZXIuTW'
    'VkaWFFdmVudC5UcmFja3NBZGRlZC5UcmFja0lkVG9UcmFja0VudHJ5Ug50cmFja0lkVG9UcmFj'
    'axpwChNUcmFja0lkVG9UcmFja0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EkMKBXZhbHVlGAIgAS'
    'gLMi0uZmlzaGphbS5tZWRpYV9ldmVudHMuc2VydmVyLk1lZGlhRXZlbnQuVHJhY2tSBXZhbHVl'
    'OgI4ARpNCg1UcmFja3NSZW1vdmVkEh8KC2VuZHBvaW50X2lkGAEgASgJUgplbmRwb2ludElkEh'
    'sKCXRyYWNrX2lkcxgCIAMoCVIIdHJhY2tJZHMaVQoNRW5kcG9pbnRBZGRlZBIfCgtlbmRwb2lu'
    'dF9pZBgBIAEoCVIKZW5kcG9pbnRJZBIjCg1tZXRhZGF0YV9qc29uGAIgASgJUgxtZXRhZGF0YU'
    'pzb24agAMKCUNvbm5lY3RlZBIfCgtlbmRwb2ludF9pZBgBIAEoCVIKZW5kcG9pbnRJZBKCAQoX'
    'ZW5kcG9pbnRfaWRfdG9fZW5kcG9pbnQYAiADKAsySy5maXNoamFtLm1lZGlhX2V2ZW50cy5zZX'
    'J2ZXIuTWVkaWFFdmVudC5Db25uZWN0ZWQuRW5kcG9pbnRJZFRvRW5kcG9pbnRFbnRyeVIUZW5k'
    'cG9pbnRJZFRvRW5kcG9pbnQSUgoLaWNlX3NlcnZlcnMYAyADKAsyMS5maXNoamFtLm1lZGlhX2'
    'V2ZW50cy5zZXJ2ZXIuTWVkaWFFdmVudC5JY2VTZXJ2ZXJSCmljZVNlcnZlcnMaeQoZRW5kcG9p'
    'bnRJZFRvRW5kcG9pbnRFbnRyeRIQCgNrZXkYASABKAlSA2tleRJGCgV2YWx1ZRgCIAEoCzIwLm'
    'Zpc2hqYW0ubWVkaWFfZXZlbnRzLnNlcnZlci5NZWRpYUV2ZW50LkVuZHBvaW50UgV2YWx1ZToC'
    'OAEaMgoPRW5kcG9pbnRSZW1vdmVkEh8KC2VuZHBvaW50X2lkGAEgASgJUgplbmRwb2ludElkGi'
    'EKBUVycm9yEhgKB21lc3NhZ2UYASABKAlSB21lc3NhZ2UapgEKCU9mZmVyRGF0YRJfCgx0cmFj'
    'a3NfdHlwZXMYASABKAsyPC5maXNoamFtLm1lZGlhX2V2ZW50cy5zZXJ2ZXIuTWVkaWFFdmVudC'
    '5PZmZlckRhdGEuVHJhY2tUeXBlc1ILdHJhY2tzVHlwZXMaOAoKVHJhY2tUeXBlcxIUCgVhdWRp'
    'bxgBIAEoBVIFYXVkaW8SFAoFdmlkZW8YAiABKAVSBXZpZGVvGsoBCglTZHBBbnN3ZXISEAoDc2'
    'RwGAEgASgJUgNzZHASagoPbWlkX3RvX3RyYWNrX2lkGAIgAygLMkMuZmlzaGphbS5tZWRpYV9l'
    'dmVudHMuc2VydmVyLk1lZGlhRXZlbnQuU2RwQW5zd2VyLk1pZFRvVHJhY2tJZEVudHJ5UgxtaW'
    'RUb1RyYWNrSWQaPwoRTWlkVG9UcmFja0lkRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFs'
    'dWUYAiABKAlSBXZhbHVlOgI4ARrNAQoPVmFkTm90aWZpY2F0aW9uEhkKCHRyYWNrX2lkGAEgAS'
    'gJUgd0cmFja0lkElYKBnN0YXR1cxgCIAEoDjI+LmZpc2hqYW0ubWVkaWFfZXZlbnRzLnNlcnZl'
    'ci5NZWRpYUV2ZW50LlZhZE5vdGlmaWNhdGlvbi5TdGF0dXNSBnN0YXR1cyJHCgZTdGF0dXMSFg'
    'oSU1RBVFVTX1VOU1BFQ0lGSUVEEAASEgoOU1RBVFVTX1NJTEVOQ0UQARIRCg1TVEFUVVNfU1BF'
    'RUNIEAIaiwEKFFRyYWNrVmFyaWFudFN3aXRjaGVkEh8KC2VuZHBvaW50X2lkGAEgASgJUgplbm'
    'Rwb2ludElkEhkKCHRyYWNrX2lkGAIgASgJUgd0cmFja0lkEjcKB3ZhcmlhbnQYAyABKA4yHS5m'
    'aXNoamFtLm1lZGlhX2V2ZW50cy5WYXJpYW50Ugd2YXJpYW50GosBChRUcmFja1ZhcmlhbnREaX'
    'NhYmxlZBIfCgtlbmRwb2ludF9pZBgBIAEoCVIKZW5kcG9pbnRJZBIZCgh0cmFja19pZBgCIAEo'
    'CVIHdHJhY2tJZBI3Cgd2YXJpYW50GAMgASgOMh0uZmlzaGphbS5tZWRpYV9ldmVudHMuVmFyaW'
    'FudFIHdmFyaWFudBqKAQoTVHJhY2tWYXJpYW50RW5hYmxlZBIfCgtlbmRwb2ludF9pZBgBIAEo'
    'CVIKZW5kcG9pbnRJZBIZCgh0cmFja19pZBgCIAEoCVIHdHJhY2tJZBI3Cgd2YXJpYW50GAMgAS'
    'gOMh0uZmlzaGphbS5tZWRpYV9ldmVudHMuVmFyaWFudFIHdmFyaWFudEIJCgdjb250ZW50');
