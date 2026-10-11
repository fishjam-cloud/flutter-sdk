// This is a generated file - do not edit.
//
// Generated from fishjam/media_events/server/server.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class MediaEvent_VadNotification_Status extends $pb.ProtobufEnum {
  static const MediaEvent_VadNotification_Status STATUS_UNSPECIFIED =
      MediaEvent_VadNotification_Status._(
          0, _omitEnumNames ? '' : 'STATUS_UNSPECIFIED');
  static const MediaEvent_VadNotification_Status STATUS_SILENCE =
      MediaEvent_VadNotification_Status._(
          1, _omitEnumNames ? '' : 'STATUS_SILENCE');
  static const MediaEvent_VadNotification_Status STATUS_SPEECH =
      MediaEvent_VadNotification_Status._(
          2, _omitEnumNames ? '' : 'STATUS_SPEECH');

  static const $core.List<MediaEvent_VadNotification_Status> values =
      <MediaEvent_VadNotification_Status>[
    STATUS_UNSPECIFIED,
    STATUS_SILENCE,
    STATUS_SPEECH,
  ];

  static final $core.List<MediaEvent_VadNotification_Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static MediaEvent_VadNotification_Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MediaEvent_VadNotification_Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
