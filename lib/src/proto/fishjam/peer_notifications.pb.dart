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

import 'media_events/peer/peer.pb.dart' as $0;
import 'media_events/server/server.pb.dart' as $1;
import 'peer_notifications.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'peer_notifications.pbenum.dart';

/// Deprecation status for SDK version
class PeerMessage_SdkDeprecation extends $pb.GeneratedMessage {
  factory PeerMessage_SdkDeprecation({
    PeerMessage_SdkDeprecation_Status? status,
    $core.String? message,
  }) {
    final result = PeerMessage_SdkDeprecation._();
    if (status != null) result.status = status;
    if (message != null) result.message = message;
    return result;
  }

  PeerMessage_SdkDeprecation._();

  factory PeerMessage_SdkDeprecation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_SdkDeprecation()..mergeFromBuffer(data, registry);
  factory PeerMessage_SdkDeprecation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_SdkDeprecation()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerMessage.SdkDeprecation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'fishjam'),
      createEmptyInstance: PeerMessage_SdkDeprecation.$_createMessage)
    ..aE<PeerMessage_SdkDeprecation_Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: PeerMessage_SdkDeprecation_Status.values)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_SdkDeprecation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_SdkDeprecation copyWith(
          void Function(PeerMessage_SdkDeprecation) updates) =>
      super.copyWith(
              (message) => updates(message as PeerMessage_SdkDeprecation))
          as PeerMessage_SdkDeprecation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PeerMessage_SdkDeprecation() / PeerMessage_SdkDeprecation.new instead')
  static PeerMessage_SdkDeprecation create() => PeerMessage_SdkDeprecation._();
  static $pb.GeneratedMessage $_createMessage() =>
      PeerMessage_SdkDeprecation._();
  @$core.override
  PeerMessage_SdkDeprecation createEmptyInstance() =>
      PeerMessage_SdkDeprecation._();
  @$core.pragma('dart2js:noInline')
  static PeerMessage_SdkDeprecation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerMessage_SdkDeprecation>(
          PeerMessage_SdkDeprecation.$_createMessage);
  static PeerMessage_SdkDeprecation? _defaultInstance;

  @$pb.TagNumber(1)
  PeerMessage_SdkDeprecation_Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(PeerMessage_SdkDeprecation_Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

/// Response sent by FJ, confirming successful authentication
class PeerMessage_Authenticated extends $pb.GeneratedMessage {
  factory PeerMessage_Authenticated({
    PeerMessage_RoomType? roomType,
    PeerMessage_SdkDeprecation? sdkDeprecation,
  }) {
    final result = PeerMessage_Authenticated._();
    if (roomType != null) result.roomType = roomType;
    if (sdkDeprecation != null) result.sdkDeprecation = sdkDeprecation;
    return result;
  }

  PeerMessage_Authenticated._();

  factory PeerMessage_Authenticated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_Authenticated()..mergeFromBuffer(data, registry);
  factory PeerMessage_Authenticated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_Authenticated()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerMessage.Authenticated',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'fishjam'),
      createEmptyInstance: PeerMessage_Authenticated.$_createMessage)
    ..aE<PeerMessage_RoomType>(1, _omitFieldNames ? '' : 'roomType',
        enumValues: PeerMessage_RoomType.values)
    ..aOM<PeerMessage_SdkDeprecation>(
        2, _omitFieldNames ? '' : 'sdkDeprecation',
        subBuilder: PeerMessage_SdkDeprecation.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_Authenticated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_Authenticated copyWith(
          void Function(PeerMessage_Authenticated) updates) =>
      super.copyWith((message) => updates(message as PeerMessage_Authenticated))
          as PeerMessage_Authenticated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PeerMessage_Authenticated() / PeerMessage_Authenticated.new instead')
  static PeerMessage_Authenticated create() => PeerMessage_Authenticated._();
  static $pb.GeneratedMessage $_createMessage() =>
      PeerMessage_Authenticated._();
  @$core.override
  PeerMessage_Authenticated createEmptyInstance() =>
      PeerMessage_Authenticated._();
  @$core.pragma('dart2js:noInline')
  static PeerMessage_Authenticated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerMessage_Authenticated>(
          PeerMessage_Authenticated.$_createMessage);
  static PeerMessage_Authenticated? _defaultInstance;

  @$pb.TagNumber(1)
  PeerMessage_RoomType get roomType => $_getN(0);
  @$pb.TagNumber(1)
  set roomType(PeerMessage_RoomType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomType() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomType() => $_clearField(1);

  @$pb.TagNumber(2)
  PeerMessage_SdkDeprecation get sdkDeprecation => $_getN(1);
  @$pb.TagNumber(2)
  set sdkDeprecation(PeerMessage_SdkDeprecation value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSdkDeprecation() => $_has(1);
  @$pb.TagNumber(2)
  void clearSdkDeprecation() => $_clearField(2);
  @$pb.TagNumber(2)
  PeerMessage_SdkDeprecation ensureSdkDeprecation() => $_ensure(1);
}

/// Request sent by peer, to authenticate to FJ server
class PeerMessage_AuthRequest extends $pb.GeneratedMessage {
  factory PeerMessage_AuthRequest({
    $core.String? token,
    $core.String? sdkVersion,
  }) {
    final result = PeerMessage_AuthRequest._();
    if (token != null) result.token = token;
    if (sdkVersion != null) result.sdkVersion = sdkVersion;
    return result;
  }

  PeerMessage_AuthRequest._();

  factory PeerMessage_AuthRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_AuthRequest()..mergeFromBuffer(data, registry);
  factory PeerMessage_AuthRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_AuthRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerMessage.AuthRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'fishjam'),
      createEmptyInstance: PeerMessage_AuthRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'sdkVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_AuthRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_AuthRequest copyWith(
          void Function(PeerMessage_AuthRequest) updates) =>
      super.copyWith((message) => updates(message as PeerMessage_AuthRequest))
          as PeerMessage_AuthRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PeerMessage_AuthRequest() / PeerMessage_AuthRequest.new instead')
  static PeerMessage_AuthRequest create() => PeerMessage_AuthRequest._();
  static $pb.GeneratedMessage $_createMessage() => PeerMessage_AuthRequest._();
  @$core.override
  PeerMessage_AuthRequest createEmptyInstance() => PeerMessage_AuthRequest._();
  @$core.pragma('dart2js:noInline')
  static PeerMessage_AuthRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerMessage_AuthRequest>(
          PeerMessage_AuthRequest.$_createMessage);
  static PeerMessage_AuthRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sdkVersion => $_getSZ(1);
  @$pb.TagNumber(2)
  set sdkVersion($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSdkVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearSdkVersion() => $_clearField(2);
}

/// PeerConnection stats sent by peer
/// https://developer.mozilla.org/en-US/docs/Web/API/RTCStatsReport#the_statistic_types
class PeerMessage_RTCStatsReport extends $pb.GeneratedMessage {
  factory PeerMessage_RTCStatsReport({
    $core.String? data,
  }) {
    final result = PeerMessage_RTCStatsReport._();
    if (data != null) result.data = data;
    return result;
  }

  PeerMessage_RTCStatsReport._();

  factory PeerMessage_RTCStatsReport.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_RTCStatsReport()..mergeFromBuffer(data, registry);
  factory PeerMessage_RTCStatsReport.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_RTCStatsReport()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerMessage.RTCStatsReport',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'fishjam'),
      createEmptyInstance: PeerMessage_RTCStatsReport.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'data')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_RTCStatsReport clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_RTCStatsReport copyWith(
          void Function(PeerMessage_RTCStatsReport) updates) =>
      super.copyWith(
              (message) => updates(message as PeerMessage_RTCStatsReport))
          as PeerMessage_RTCStatsReport;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PeerMessage_RTCStatsReport() / PeerMessage_RTCStatsReport.new instead')
  static PeerMessage_RTCStatsReport create() => PeerMessage_RTCStatsReport._();
  static $pb.GeneratedMessage $_createMessage() =>
      PeerMessage_RTCStatsReport._();
  @$core.override
  PeerMessage_RTCStatsReport createEmptyInstance() =>
      PeerMessage_RTCStatsReport._();
  @$core.pragma('dart2js:noInline')
  static PeerMessage_RTCStatsReport getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerMessage_RTCStatsReport>(
          PeerMessage_RTCStatsReport.$_createMessage);
  static PeerMessage_RTCStatsReport? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get data => $_getSZ(0);
  @$pb.TagNumber(1)
  set data($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
}

/// Any type of WebRTC messages passed between FJ and peer
class PeerMessage_MediaEvent extends $pb.GeneratedMessage {
  factory PeerMessage_MediaEvent({
    $core.String? data,
  }) {
    final result = PeerMessage_MediaEvent._();
    if (data != null) result.data = data;
    return result;
  }

  PeerMessage_MediaEvent._();

  factory PeerMessage_MediaEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_MediaEvent()..mergeFromBuffer(data, registry);
  factory PeerMessage_MediaEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage_MediaEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerMessage.MediaEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'fishjam'),
      createEmptyInstance: PeerMessage_MediaEvent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'data')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_MediaEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage_MediaEvent copyWith(
          void Function(PeerMessage_MediaEvent) updates) =>
      super.copyWith((message) => updates(message as PeerMessage_MediaEvent))
          as PeerMessage_MediaEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PeerMessage_MediaEvent() / PeerMessage_MediaEvent.new instead')
  static PeerMessage_MediaEvent create() => PeerMessage_MediaEvent._();
  static $pb.GeneratedMessage $_createMessage() => PeerMessage_MediaEvent._();
  @$core.override
  PeerMessage_MediaEvent createEmptyInstance() => PeerMessage_MediaEvent._();
  @$core.pragma('dart2js:noInline')
  static PeerMessage_MediaEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerMessage_MediaEvent>(
          PeerMessage_MediaEvent.$_createMessage);
  static PeerMessage_MediaEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get data => $_getSZ(0);
  @$pb.TagNumber(1)
  set data($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
}

enum PeerMessage_Content {
  authenticated,
  authRequest,
  mediaEvent,
  rtcStatsReport,
  peerMediaEvent,
  serverMediaEvent,
  notSet
}

/// Defines any type of message sent between FJ and a peer
class PeerMessage extends $pb.GeneratedMessage {
  factory PeerMessage({
    PeerMessage_Authenticated? authenticated,
    PeerMessage_AuthRequest? authRequest,
    PeerMessage_MediaEvent? mediaEvent,
    PeerMessage_RTCStatsReport? rtcStatsReport,
    $0.MediaEvent? peerMediaEvent,
    $1.MediaEvent? serverMediaEvent,
  }) {
    final result = PeerMessage._();
    if (authenticated != null) result.authenticated = authenticated;
    if (authRequest != null) result.authRequest = authRequest;
    if (mediaEvent != null) result.mediaEvent = mediaEvent;
    if (rtcStatsReport != null) result.rtcStatsReport = rtcStatsReport;
    if (peerMediaEvent != null) result.peerMediaEvent = peerMediaEvent;
    if (serverMediaEvent != null) result.serverMediaEvent = serverMediaEvent;
    return result;
  }

  PeerMessage._();

  factory PeerMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage()..mergeFromBuffer(data, registry);
  factory PeerMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerMessage()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, PeerMessage_Content>
      _PeerMessage_ContentByTag = {
    1: PeerMessage_Content.authenticated,
    2: PeerMessage_Content.authRequest,
    3: PeerMessage_Content.mediaEvent,
    4: PeerMessage_Content.rtcStatsReport,
    5: PeerMessage_Content.peerMediaEvent,
    6: PeerMessage_Content.serverMediaEvent,
    0: PeerMessage_Content.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'fishjam'),
      createEmptyInstance: PeerMessage.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6])
    ..aOM<PeerMessage_Authenticated>(1, _omitFieldNames ? '' : 'authenticated',
        subBuilder: PeerMessage_Authenticated.$_createMessage)
    ..aOM<PeerMessage_AuthRequest>(2, _omitFieldNames ? '' : 'authRequest',
        subBuilder: PeerMessage_AuthRequest.$_createMessage)
    ..aOM<PeerMessage_MediaEvent>(3, _omitFieldNames ? '' : 'mediaEvent',
        subBuilder: PeerMessage_MediaEvent.$_createMessage)
    ..aOM<PeerMessage_RTCStatsReport>(
        4, _omitFieldNames ? '' : 'rtcStatsReport',
        subBuilder: PeerMessage_RTCStatsReport.$_createMessage)
    ..aOM<$0.MediaEvent>(5, _omitFieldNames ? '' : 'peerMediaEvent',
        subBuilder: $0.MediaEvent.$_createMessage)
    ..aOM<$1.MediaEvent>(6, _omitFieldNames ? '' : 'serverMediaEvent',
        subBuilder: $1.MediaEvent.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerMessage copyWith(void Function(PeerMessage) updates) =>
      super.copyWith((message) => updates(message as PeerMessage))
          as PeerMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PeerMessage() / PeerMessage.new instead')
  static PeerMessage create() => PeerMessage._();
  static $pb.GeneratedMessage $_createMessage() => PeerMessage._();
  @$core.override
  PeerMessage createEmptyInstance() => PeerMessage._();
  @$core.pragma('dart2js:noInline')
  static PeerMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerMessage>(
          PeerMessage.$_createMessage);
  static PeerMessage? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  PeerMessage_Content whichContent() =>
      _PeerMessage_ContentByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearContent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  PeerMessage_Authenticated get authenticated => $_getN(0);
  @$pb.TagNumber(1)
  set authenticated(PeerMessage_Authenticated value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthenticated() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthenticated() => $_clearField(1);
  @$pb.TagNumber(1)
  PeerMessage_Authenticated ensureAuthenticated() => $_ensure(0);

  @$pb.TagNumber(2)
  PeerMessage_AuthRequest get authRequest => $_getN(1);
  @$pb.TagNumber(2)
  set authRequest(PeerMessage_AuthRequest value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthRequest() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthRequest() => $_clearField(2);
  @$pb.TagNumber(2)
  PeerMessage_AuthRequest ensureAuthRequest() => $_ensure(1);

  @$pb.TagNumber(3)
  PeerMessage_MediaEvent get mediaEvent => $_getN(2);
  @$pb.TagNumber(3)
  set mediaEvent(PeerMessage_MediaEvent value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMediaEvent() => $_has(2);
  @$pb.TagNumber(3)
  void clearMediaEvent() => $_clearField(3);
  @$pb.TagNumber(3)
  PeerMessage_MediaEvent ensureMediaEvent() => $_ensure(2);

  @$pb.TagNumber(4)
  PeerMessage_RTCStatsReport get rtcStatsReport => $_getN(3);
  @$pb.TagNumber(4)
  set rtcStatsReport(PeerMessage_RTCStatsReport value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRtcStatsReport() => $_has(3);
  @$pb.TagNumber(4)
  void clearRtcStatsReport() => $_clearField(4);
  @$pb.TagNumber(4)
  PeerMessage_RTCStatsReport ensureRtcStatsReport() => $_ensure(3);

  @$pb.TagNumber(5)
  $0.MediaEvent get peerMediaEvent => $_getN(4);
  @$pb.TagNumber(5)
  set peerMediaEvent($0.MediaEvent value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPeerMediaEvent() => $_has(4);
  @$pb.TagNumber(5)
  void clearPeerMediaEvent() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.MediaEvent ensurePeerMediaEvent() => $_ensure(4);

  @$pb.TagNumber(6)
  $1.MediaEvent get serverMediaEvent => $_getN(5);
  @$pb.TagNumber(6)
  set serverMediaEvent($1.MediaEvent value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasServerMediaEvent() => $_has(5);
  @$pb.TagNumber(6)
  void clearServerMediaEvent() => $_clearField(6);
  @$pb.TagNumber(6)
  $1.MediaEvent ensureServerMediaEvent() => $_ensure(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
