// This is a generated file - do not edit.
//
// Generated from fishjam/media_events/shared.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Variant extends $pb.ProtobufEnum {
  static const Variant VARIANT_UNSPECIFIED =
      Variant._(0, _omitEnumNames ? '' : 'VARIANT_UNSPECIFIED');
  static const Variant VARIANT_LOW =
      Variant._(1, _omitEnumNames ? '' : 'VARIANT_LOW');
  static const Variant VARIANT_MEDIUM =
      Variant._(2, _omitEnumNames ? '' : 'VARIANT_MEDIUM');
  static const Variant VARIANT_HIGH =
      Variant._(3, _omitEnumNames ? '' : 'VARIANT_HIGH');

  static const $core.List<Variant> values = <Variant>[
    VARIANT_UNSPECIFIED,
    VARIANT_LOW,
    VARIANT_MEDIUM,
    VARIANT_HIGH,
  ];

  static final $core.List<Variant?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Variant? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Variant._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
