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

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'shared.pbenum.dart';

/// Contains information about an ICE candidate which will be sent to the peer/server
class Candidate extends $pb.GeneratedMessage {
  factory Candidate({
    $core.String? candidate,
    $core.int? sdpMLineIndex,
    $core.String? sdpMid,
    $core.String? usernameFragment,
  }) {
    final result = Candidate._();
    if (candidate != null) result.candidate = candidate;
    if (sdpMLineIndex != null) result.sdpMLineIndex = sdpMLineIndex;
    if (sdpMid != null) result.sdpMid = sdpMid;
    if (usernameFragment != null) result.usernameFragment = usernameFragment;
    return result;
  }

  Candidate._();

  factory Candidate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Candidate()..mergeFromBuffer(data, registry);
  factory Candidate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Candidate()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Candidate',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events'),
      createEmptyInstance: Candidate.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'candidate')
    ..aI(2, _omitFieldNames ? '' : 'sdpMLineIndex')
    ..aOS(3, _omitFieldNames ? '' : 'sdpMid')
    ..aOS(4, _omitFieldNames ? '' : 'usernameFragment')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Candidate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Candidate copyWith(void Function(Candidate) updates) =>
      super.copyWith((message) => updates(message as Candidate)) as Candidate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Candidate() / Candidate.new instead')
  static Candidate create() => Candidate._();
  static $pb.GeneratedMessage $_createMessage() => Candidate._();
  @$core.override
  Candidate createEmptyInstance() => Candidate._();
  @$core.pragma('dart2js:noInline')
  static Candidate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Candidate>(Candidate.$_createMessage);
  static Candidate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get candidate => $_getSZ(0);
  @$pb.TagNumber(1)
  set candidate($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCandidate() => $_has(0);
  @$pb.TagNumber(1)
  void clearCandidate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get sdpMLineIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set sdpMLineIndex($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSdpMLineIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearSdpMLineIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sdpMid => $_getSZ(2);
  @$pb.TagNumber(3)
  set sdpMid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSdpMid() => $_has(2);
  @$pb.TagNumber(3)
  void clearSdpMid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get usernameFragment => $_getSZ(3);
  @$pb.TagNumber(4)
  set usernameFragment($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUsernameFragment() => $_has(3);
  @$pb.TagNumber(4)
  void clearUsernameFragment() => $_clearField(4);
}

class ChannelMessageBinaryPayload extends $pb.GeneratedMessage {
  factory ChannelMessageBinaryPayload({
    $core.List<$core.int>? data,
  }) {
    final result = ChannelMessageBinaryPayload._();
    if (data != null) result.data = data;
    return result;
  }

  ChannelMessageBinaryPayload._();

  factory ChannelMessageBinaryPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChannelMessageBinaryPayload()..mergeFromBuffer(data, registry);
  factory ChannelMessageBinaryPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChannelMessageBinaryPayload()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChannelMessageBinaryPayload',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events'),
      createEmptyInstance: ChannelMessageBinaryPayload.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelMessageBinaryPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelMessageBinaryPayload copyWith(
          void Function(ChannelMessageBinaryPayload) updates) =>
      super.copyWith(
              (message) => updates(message as ChannelMessageBinaryPayload))
          as ChannelMessageBinaryPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ChannelMessageBinaryPayload() / ChannelMessageBinaryPayload.new instead')
  static ChannelMessageBinaryPayload create() =>
      ChannelMessageBinaryPayload._();
  static $pb.GeneratedMessage $_createMessage() =>
      ChannelMessageBinaryPayload._();
  @$core.override
  ChannelMessageBinaryPayload createEmptyInstance() =>
      ChannelMessageBinaryPayload._();
  @$core.pragma('dart2js:noInline')
  static ChannelMessageBinaryPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChannelMessageBinaryPayload>(
          ChannelMessageBinaryPayload.$_createMessage);
  static ChannelMessageBinaryPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
}

enum ChannelMessage_Payload { binary, notSet }

class ChannelMessage extends $pb.GeneratedMessage {
  factory ChannelMessage({
    $core.String? source,
    $core.Iterable<$core.String>? destinations,
    ChannelMessageBinaryPayload? binary,
  }) {
    final result = ChannelMessage._();
    if (source != null) result.source = source;
    if (destinations != null) result.destinations.addAll(destinations);
    if (binary != null) result.binary = binary;
    return result;
  }

  ChannelMessage._();

  factory ChannelMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChannelMessage()..mergeFromBuffer(data, registry);
  factory ChannelMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChannelMessage()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ChannelMessage_Payload>
      _ChannelMessage_PayloadByTag = {
    3: ChannelMessage_Payload.binary,
    0: ChannelMessage_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChannelMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events'),
      createEmptyInstance: ChannelMessage.$_createMessage)
    ..oo(0, [3])
    ..aOS(1, _omitFieldNames ? '' : 'source')
    ..pPS(2, _omitFieldNames ? '' : 'destinations')
    ..aOM<ChannelMessageBinaryPayload>(3, _omitFieldNames ? '' : 'binary',
        subBuilder: ChannelMessageBinaryPayload.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChannelMessage copyWith(void Function(ChannelMessage) updates) =>
      super.copyWith((message) => updates(message as ChannelMessage))
          as ChannelMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChannelMessage() / ChannelMessage.new instead')
  static ChannelMessage create() => ChannelMessage._();
  static $pb.GeneratedMessage $_createMessage() => ChannelMessage._();
  @$core.override
  ChannelMessage createEmptyInstance() => ChannelMessage._();
  @$core.pragma('dart2js:noInline')
  static ChannelMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChannelMessage>(
          ChannelMessage.$_createMessage);
  static ChannelMessage? _defaultInstance;

  @$pb.TagNumber(3)
  ChannelMessage_Payload whichPayload() =>
      _ChannelMessage_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get destinations => $_getList(1);

  @$pb.TagNumber(3)
  ChannelMessageBinaryPayload get binary => $_getN(2);
  @$pb.TagNumber(3)
  set binary(ChannelMessageBinaryPayload value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasBinary() => $_has(2);
  @$pb.TagNumber(3)
  void clearBinary() => $_clearField(3);
  @$pb.TagNumber(3)
  ChannelMessageBinaryPayload ensureBinary() => $_ensure(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
