// This is a generated file - do not edit.
//
// Generated from fishjam/peer_notifications.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Defines types of rooms peers may connect to
class PeerMessage_RoomType extends $pb.ProtobufEnum {
  static const PeerMessage_RoomType ROOM_TYPE_UNSPECIFIED =
      PeerMessage_RoomType._(0, _omitEnumNames ? '' : 'ROOM_TYPE_UNSPECIFIED');
  static const PeerMessage_RoomType ROOM_TYPE_CONFERENCE =
      PeerMessage_RoomType._(1, _omitEnumNames ? '' : 'ROOM_TYPE_CONFERENCE');
  static const PeerMessage_RoomType ROOM_TYPE_AUDIO_ONLY =
      PeerMessage_RoomType._(2, _omitEnumNames ? '' : 'ROOM_TYPE_AUDIO_ONLY');
  static const PeerMessage_RoomType ROOM_TYPE_LIVESTREAM =
      PeerMessage_RoomType._(3, _omitEnumNames ? '' : 'ROOM_TYPE_LIVESTREAM');

  static const $core.List<PeerMessage_RoomType> values = <PeerMessage_RoomType>[
    ROOM_TYPE_UNSPECIFIED,
    ROOM_TYPE_CONFERENCE,
    ROOM_TYPE_AUDIO_ONLY,
    ROOM_TYPE_LIVESTREAM,
  ];

  static final $core.List<PeerMessage_RoomType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PeerMessage_RoomType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PeerMessage_RoomType._(super.value, super.name);
}

class PeerMessage_SdkDeprecation_Status extends $pb.ProtobufEnum {
  static const PeerMessage_SdkDeprecation_Status STATUS_UNSPECIFIED =
      PeerMessage_SdkDeprecation_Status._(
          0, _omitEnumNames ? '' : 'STATUS_UNSPECIFIED');
  static const PeerMessage_SdkDeprecation_Status STATUS_UP_TO_DATE =
      PeerMessage_SdkDeprecation_Status._(
          1, _omitEnumNames ? '' : 'STATUS_UP_TO_DATE');
  static const PeerMessage_SdkDeprecation_Status STATUS_DEPRECATED =
      PeerMessage_SdkDeprecation_Status._(
          2, _omitEnumNames ? '' : 'STATUS_DEPRECATED');
  static const PeerMessage_SdkDeprecation_Status STATUS_UNSUPPORTED =
      PeerMessage_SdkDeprecation_Status._(
          3, _omitEnumNames ? '' : 'STATUS_UNSUPPORTED');

  static const $core.List<PeerMessage_SdkDeprecation_Status> values =
      <PeerMessage_SdkDeprecation_Status>[
    STATUS_UNSPECIFIED,
    STATUS_UP_TO_DATE,
    STATUS_DEPRECATED,
    STATUS_UNSUPPORTED,
  ];

  static final $core.List<PeerMessage_SdkDeprecation_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PeerMessage_SdkDeprecation_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PeerMessage_SdkDeprecation_Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
