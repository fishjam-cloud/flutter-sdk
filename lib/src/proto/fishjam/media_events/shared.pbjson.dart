// This is a generated file - do not edit.
//
// Generated from fishjam/media_events/shared.proto.

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

@$core.Deprecated('Use variantDescriptor instead')
const Variant$json = {
  '1': 'Variant',
  '2': [
    {'1': 'VARIANT_UNSPECIFIED', '2': 0},
    {'1': 'VARIANT_LOW', '2': 1},
    {'1': 'VARIANT_MEDIUM', '2': 2},
    {'1': 'VARIANT_HIGH', '2': 3},
  ],
};

/// Descriptor for `Variant`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List variantDescriptor = $convert.base64Decode(
    'CgdWYXJpYW50EhcKE1ZBUklBTlRfVU5TUEVDSUZJRUQQABIPCgtWQVJJQU5UX0xPVxABEhIKDl'
    'ZBUklBTlRfTUVESVVNEAISEAoMVkFSSUFOVF9ISUdIEAM=');

@$core.Deprecated('Use candidateDescriptor instead')
const Candidate$json = {
  '1': 'Candidate',
  '2': [
    {'1': 'candidate', '3': 1, '4': 1, '5': 9, '10': 'candidate'},
    {'1': 'sdp_m_line_index', '3': 2, '4': 1, '5': 5, '10': 'sdpMLineIndex'},
    {'1': 'sdp_mid', '3': 3, '4': 1, '5': 9, '10': 'sdpMid'},
    {
      '1': 'username_fragment',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'usernameFragment'
    },
  ],
};

/// Descriptor for `Candidate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List candidateDescriptor = $convert.base64Decode(
    'CglDYW5kaWRhdGUSHAoJY2FuZGlkYXRlGAEgASgJUgljYW5kaWRhdGUSJwoQc2RwX21fbGluZV'
    '9pbmRleBgCIAEoBVINc2RwTUxpbmVJbmRleBIXCgdzZHBfbWlkGAMgASgJUgZzZHBNaWQSKwoR'
    'dXNlcm5hbWVfZnJhZ21lbnQYBCABKAlSEHVzZXJuYW1lRnJhZ21lbnQ=');

@$core.Deprecated('Use channelMessageBinaryPayloadDescriptor instead')
const ChannelMessageBinaryPayload$json = {
  '1': 'ChannelMessageBinaryPayload',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `ChannelMessageBinaryPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelMessageBinaryPayloadDescriptor =
    $convert.base64Decode(
        'ChtDaGFubmVsTWVzc2FnZUJpbmFyeVBheWxvYWQSEgoEZGF0YRgBIAEoDFIEZGF0YQ==');

@$core.Deprecated('Use channelMessageDescriptor instead')
const ChannelMessage$json = {
  '1': 'ChannelMessage',
  '2': [
    {'1': 'source', '3': 1, '4': 1, '5': 9, '10': 'source'},
    {'1': 'destinations', '3': 2, '4': 3, '5': 9, '10': 'destinations'},
    {
      '1': 'binary',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.fishjam.media_events.ChannelMessageBinaryPayload',
      '9': 0,
      '10': 'binary'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `ChannelMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelMessageDescriptor = $convert.base64Decode(
    'Cg5DaGFubmVsTWVzc2FnZRIWCgZzb3VyY2UYASABKAlSBnNvdXJjZRIiCgxkZXN0aW5hdGlvbn'
    'MYAiADKAlSDGRlc3RpbmF0aW9ucxJLCgZiaW5hcnkYAyABKAsyMS5maXNoamFtLm1lZGlhX2V2'
    'ZW50cy5DaGFubmVsTWVzc2FnZUJpbmFyeVBheWxvYWRIAFIGYmluYXJ5QgkKB3BheWxvYWQ=');
