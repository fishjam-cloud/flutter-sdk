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

import '../shared.pb.dart' as $0;
import 'server.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'server.pbenum.dart';

class MediaEvent_Track_SimulcastConfig extends $pb.GeneratedMessage {
  factory MediaEvent_Track_SimulcastConfig({
    $core.bool? enabled,
    $core.Iterable<$0.Variant>? enabledVariants,
    $core.Iterable<$0.Variant>? disabledVariants,
  }) {
    final result = MediaEvent_Track_SimulcastConfig._();
    if (enabled != null) result.enabled = enabled;
    if (enabledVariants != null) result.enabledVariants.addAll(enabledVariants);
    if (disabledVariants != null)
      result.disabledVariants.addAll(disabledVariants);
    return result;
  }

  MediaEvent_Track_SimulcastConfig._();

  factory MediaEvent_Track_SimulcastConfig.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Track_SimulcastConfig()..mergeFromBuffer(data, registry);
  factory MediaEvent_Track_SimulcastConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Track_SimulcastConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.Track.SimulcastConfig',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_Track_SimulcastConfig.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'enabled')
    ..pc<$0.Variant>(
        2, _omitFieldNames ? '' : 'enabledVariants', $pb.PbFieldType.KE,
        valueOf: $0.Variant.valueOf,
        enumValues: $0.Variant.values,
        defaultEnumValue: $0.Variant.VARIANT_UNSPECIFIED)
    ..pc<$0.Variant>(
        3, _omitFieldNames ? '' : 'disabledVariants', $pb.PbFieldType.KE,
        valueOf: $0.Variant.valueOf,
        enumValues: $0.Variant.values,
        defaultEnumValue: $0.Variant.VARIANT_UNSPECIFIED)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Track_SimulcastConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Track_SimulcastConfig copyWith(
          void Function(MediaEvent_Track_SimulcastConfig) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_Track_SimulcastConfig))
          as MediaEvent_Track_SimulcastConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_Track_SimulcastConfig() / MediaEvent_Track_SimulcastConfig.new instead')
  static MediaEvent_Track_SimulcastConfig create() =>
      MediaEvent_Track_SimulcastConfig._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_Track_SimulcastConfig._();
  @$core.override
  MediaEvent_Track_SimulcastConfig createEmptyInstance() =>
      MediaEvent_Track_SimulcastConfig._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_Track_SimulcastConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_Track_SimulcastConfig>(
          MediaEvent_Track_SimulcastConfig.$_createMessage);
  static MediaEvent_Track_SimulcastConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get enabled => $_getBF(0);
  @$pb.TagNumber(1)
  set enabled($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEnabled() => $_has(0);
  @$pb.TagNumber(1)
  void clearEnabled() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$0.Variant> get enabledVariants => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$0.Variant> get disabledVariants => $_getList(2);
}

/// SCHEMAS
class MediaEvent_Track extends $pb.GeneratedMessage {
  factory MediaEvent_Track({
    $core.String? metadataJson,
    MediaEvent_Track_SimulcastConfig? simulcastConfig,
  }) {
    final result = MediaEvent_Track._();
    if (metadataJson != null) result.metadataJson = metadataJson;
    if (simulcastConfig != null) result.simulcastConfig = simulcastConfig;
    return result;
  }

  MediaEvent_Track._();

  factory MediaEvent_Track.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Track()..mergeFromBuffer(data, registry);
  factory MediaEvent_Track.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Track()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.Track',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_Track.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'metadataJson')
    ..aOM<MediaEvent_Track_SimulcastConfig>(
        2, _omitFieldNames ? '' : 'simulcastConfig',
        subBuilder: MediaEvent_Track_SimulcastConfig.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Track clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Track copyWith(void Function(MediaEvent_Track) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_Track))
          as MediaEvent_Track;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MediaEvent_Track() / MediaEvent_Track.new instead')
  static MediaEvent_Track create() => MediaEvent_Track._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_Track._();
  @$core.override
  MediaEvent_Track createEmptyInstance() => MediaEvent_Track._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_Track getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MediaEvent_Track>(
          MediaEvent_Track.$_createMessage);
  static MediaEvent_Track? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get metadataJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set metadataJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMetadataJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearMetadataJson() => $_clearField(1);

  @$pb.TagNumber(2)
  MediaEvent_Track_SimulcastConfig get simulcastConfig => $_getN(1);
  @$pb.TagNumber(2)
  set simulcastConfig(MediaEvent_Track_SimulcastConfig value) =>
      $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSimulcastConfig() => $_has(1);
  @$pb.TagNumber(2)
  void clearSimulcastConfig() => $_clearField(2);
  @$pb.TagNumber(2)
  MediaEvent_Track_SimulcastConfig ensureSimulcastConfig() => $_ensure(1);
}

class MediaEvent_Endpoint extends $pb.GeneratedMessage {
  factory MediaEvent_Endpoint({
    $core.String? endpointType,
    $core.String? metadataJson,
    $core.Iterable<$core.MapEntry<$core.String, MediaEvent_Track>>?
        trackIdToTrack,
  }) {
    final result = MediaEvent_Endpoint._();
    if (endpointType != null) result.endpointType = endpointType;
    if (metadataJson != null) result.metadataJson = metadataJson;
    if (trackIdToTrack != null)
      result.trackIdToTrack.addEntries(trackIdToTrack);
    return result;
  }

  MediaEvent_Endpoint._();

  factory MediaEvent_Endpoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Endpoint()..mergeFromBuffer(data, registry);
  factory MediaEvent_Endpoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Endpoint()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.Endpoint',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_Endpoint.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'endpointType')
    ..aOS(3, _omitFieldNames ? '' : 'metadataJson')
    ..m<$core.String, MediaEvent_Track>(
        4, _omitFieldNames ? '' : 'trackIdToTrack',
        entryClassName: 'MediaEvent.Endpoint.TrackIdToTrackEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: MediaEvent_Track.$_createMessage,
        valueDefaultOrMaker: MediaEvent_Track.getDefault,
        packageName: const $pb.PackageName('fishjam.media_events.server'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Endpoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Endpoint copyWith(void Function(MediaEvent_Endpoint) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_Endpoint))
          as MediaEvent_Endpoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use MediaEvent_Endpoint() / MediaEvent_Endpoint.new instead')
  static MediaEvent_Endpoint create() => MediaEvent_Endpoint._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_Endpoint._();
  @$core.override
  MediaEvent_Endpoint createEmptyInstance() => MediaEvent_Endpoint._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_Endpoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_Endpoint>(
          MediaEvent_Endpoint.$_createMessage);
  static MediaEvent_Endpoint? _defaultInstance;

  @$pb.TagNumber(2)
  $core.String get endpointType => $_getSZ(0);
  @$pb.TagNumber(2)
  set endpointType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(2)
  $core.bool hasEndpointType() => $_has(0);
  @$pb.TagNumber(2)
  void clearEndpointType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get metadataJson => $_getSZ(1);
  @$pb.TagNumber(3)
  set metadataJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasMetadataJson() => $_has(1);
  @$pb.TagNumber(3)
  void clearMetadataJson() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, MediaEvent_Track> get trackIdToTrack => $_getMap(2);
}

class MediaEvent_IceServer extends $pb.GeneratedMessage {
  factory MediaEvent_IceServer({
    $core.String? credential,
    $core.Iterable<$core.String>? urls,
    $core.String? username,
  }) {
    final result = MediaEvent_IceServer._();
    if (credential != null) result.credential = credential;
    if (urls != null) result.urls.addAll(urls);
    if (username != null) result.username = username;
    return result;
  }

  MediaEvent_IceServer._();

  factory MediaEvent_IceServer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_IceServer()..mergeFromBuffer(data, registry);
  factory MediaEvent_IceServer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_IceServer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.IceServer',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_IceServer.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'credential')
    ..pPS(2, _omitFieldNames ? '' : 'urls')
    ..aOS(3, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_IceServer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_IceServer copyWith(void Function(MediaEvent_IceServer) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_IceServer))
          as MediaEvent_IceServer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_IceServer() / MediaEvent_IceServer.new instead')
  static MediaEvent_IceServer create() => MediaEvent_IceServer._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_IceServer._();
  @$core.override
  MediaEvent_IceServer createEmptyInstance() => MediaEvent_IceServer._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_IceServer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_IceServer>(
          MediaEvent_IceServer.$_createMessage);
  static MediaEvent_IceServer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get credential => $_getSZ(0);
  @$pb.TagNumber(1)
  set credential($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCredential() => $_has(0);
  @$pb.TagNumber(1)
  void clearCredential() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get urls => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get username => $_getSZ(2);
  @$pb.TagNumber(3)
  set username($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUsername() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsername() => $_clearField(3);
}

/// Sent when metadata of one of the endpoints was updated
class MediaEvent_EndpointUpdated extends $pb.GeneratedMessage {
  factory MediaEvent_EndpointUpdated({
    $core.String? endpointId,
    $core.String? metadataJson,
  }) {
    final result = MediaEvent_EndpointUpdated._();
    if (endpointId != null) result.endpointId = endpointId;
    if (metadataJson != null) result.metadataJson = metadataJson;
    return result;
  }

  MediaEvent_EndpointUpdated._();

  factory MediaEvent_EndpointUpdated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_EndpointUpdated()..mergeFromBuffer(data, registry);
  factory MediaEvent_EndpointUpdated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_EndpointUpdated()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.EndpointUpdated',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_EndpointUpdated.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..aOS(2, _omitFieldNames ? '' : 'metadataJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_EndpointUpdated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_EndpointUpdated copyWith(
          void Function(MediaEvent_EndpointUpdated) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_EndpointUpdated))
          as MediaEvent_EndpointUpdated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_EndpointUpdated() / MediaEvent_EndpointUpdated.new instead')
  static MediaEvent_EndpointUpdated create() => MediaEvent_EndpointUpdated._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_EndpointUpdated._();
  @$core.override
  MediaEvent_EndpointUpdated createEmptyInstance() =>
      MediaEvent_EndpointUpdated._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_EndpointUpdated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_EndpointUpdated>(
          MediaEvent_EndpointUpdated.$_createMessage);
  static MediaEvent_EndpointUpdated? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get metadataJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set metadataJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMetadataJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearMetadataJson() => $_clearField(2);
}

/// Sent when metadata of one of the tracks was updated
class MediaEvent_TrackUpdated extends $pb.GeneratedMessage {
  factory MediaEvent_TrackUpdated({
    $core.String? endpointId,
    $core.String? trackId,
    $core.String? metadataJson,
  }) {
    final result = MediaEvent_TrackUpdated._();
    if (endpointId != null) result.endpointId = endpointId;
    if (trackId != null) result.trackId = trackId;
    if (metadataJson != null) result.metadataJson = metadataJson;
    return result;
  }

  MediaEvent_TrackUpdated._();

  factory MediaEvent_TrackUpdated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackUpdated()..mergeFromBuffer(data, registry);
  factory MediaEvent_TrackUpdated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackUpdated()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.TrackUpdated',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_TrackUpdated.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..aOS(2, _omitFieldNames ? '' : 'trackId')
    ..aOS(3, _omitFieldNames ? '' : 'metadataJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackUpdated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackUpdated copyWith(
          void Function(MediaEvent_TrackUpdated) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_TrackUpdated))
          as MediaEvent_TrackUpdated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_TrackUpdated() / MediaEvent_TrackUpdated.new instead')
  static MediaEvent_TrackUpdated create() => MediaEvent_TrackUpdated._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_TrackUpdated._();
  @$core.override
  MediaEvent_TrackUpdated createEmptyInstance() => MediaEvent_TrackUpdated._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_TrackUpdated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_TrackUpdated>(
          MediaEvent_TrackUpdated.$_createMessage);
  static MediaEvent_TrackUpdated? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get trackId => $_getSZ(1);
  @$pb.TagNumber(2)
  set trackId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTrackId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrackId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get metadataJson => $_getSZ(2);
  @$pb.TagNumber(3)
  set metadataJson($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMetadataJson() => $_has(2);
  @$pb.TagNumber(3)
  void clearMetadataJson() => $_clearField(3);
}

/// Sent to informs that one of the peers has added one or more tracks.
class MediaEvent_TracksAdded extends $pb.GeneratedMessage {
  factory MediaEvent_TracksAdded({
    $core.String? endpointId,
    $core.Iterable<$core.MapEntry<$core.String, MediaEvent_Track>>?
        trackIdToTrack,
  }) {
    final result = MediaEvent_TracksAdded._();
    if (endpointId != null) result.endpointId = endpointId;
    if (trackIdToTrack != null)
      result.trackIdToTrack.addEntries(trackIdToTrack);
    return result;
  }

  MediaEvent_TracksAdded._();

  factory MediaEvent_TracksAdded.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TracksAdded()..mergeFromBuffer(data, registry);
  factory MediaEvent_TracksAdded.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TracksAdded()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.TracksAdded',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_TracksAdded.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..m<$core.String, MediaEvent_Track>(
        2, _omitFieldNames ? '' : 'trackIdToTrack',
        entryClassName: 'MediaEvent.TracksAdded.TrackIdToTrackEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: MediaEvent_Track.$_createMessage,
        valueDefaultOrMaker: MediaEvent_Track.getDefault,
        packageName: const $pb.PackageName('fishjam.media_events.server'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TracksAdded clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TracksAdded copyWith(
          void Function(MediaEvent_TracksAdded) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_TracksAdded))
          as MediaEvent_TracksAdded;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_TracksAdded() / MediaEvent_TracksAdded.new instead')
  static MediaEvent_TracksAdded create() => MediaEvent_TracksAdded._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_TracksAdded._();
  @$core.override
  MediaEvent_TracksAdded createEmptyInstance() => MediaEvent_TracksAdded._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_TracksAdded getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_TracksAdded>(
          MediaEvent_TracksAdded.$_createMessage);
  static MediaEvent_TracksAdded? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, MediaEvent_Track> get trackIdToTrack => $_getMap(1);
}

/// Sent to informs that one of the peers has removed one or more tracks.
class MediaEvent_TracksRemoved extends $pb.GeneratedMessage {
  factory MediaEvent_TracksRemoved({
    $core.String? endpointId,
    $core.Iterable<$core.String>? trackIds,
  }) {
    final result = MediaEvent_TracksRemoved._();
    if (endpointId != null) result.endpointId = endpointId;
    if (trackIds != null) result.trackIds.addAll(trackIds);
    return result;
  }

  MediaEvent_TracksRemoved._();

  factory MediaEvent_TracksRemoved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TracksRemoved()..mergeFromBuffer(data, registry);
  factory MediaEvent_TracksRemoved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TracksRemoved()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.TracksRemoved',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_TracksRemoved.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..pPS(2, _omitFieldNames ? '' : 'trackIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TracksRemoved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TracksRemoved copyWith(
          void Function(MediaEvent_TracksRemoved) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_TracksRemoved))
          as MediaEvent_TracksRemoved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_TracksRemoved() / MediaEvent_TracksRemoved.new instead')
  static MediaEvent_TracksRemoved create() => MediaEvent_TracksRemoved._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_TracksRemoved._();
  @$core.override
  MediaEvent_TracksRemoved createEmptyInstance() =>
      MediaEvent_TracksRemoved._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_TracksRemoved getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_TracksRemoved>(
          MediaEvent_TracksRemoved.$_createMessage);
  static MediaEvent_TracksRemoved? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get trackIds => $_getList(1);
}

/// Sent to all peers in the room after a new endpoint was added.
class MediaEvent_EndpointAdded extends $pb.GeneratedMessage {
  factory MediaEvent_EndpointAdded({
    $core.String? endpointId,
    $core.String? metadataJson,
  }) {
    final result = MediaEvent_EndpointAdded._();
    if (endpointId != null) result.endpointId = endpointId;
    if (metadataJson != null) result.metadataJson = metadataJson;
    return result;
  }

  MediaEvent_EndpointAdded._();

  factory MediaEvent_EndpointAdded.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_EndpointAdded()..mergeFromBuffer(data, registry);
  factory MediaEvent_EndpointAdded.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_EndpointAdded()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.EndpointAdded',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_EndpointAdded.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..aOS(2, _omitFieldNames ? '' : 'metadataJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_EndpointAdded clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_EndpointAdded copyWith(
          void Function(MediaEvent_EndpointAdded) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_EndpointAdded))
          as MediaEvent_EndpointAdded;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_EndpointAdded() / MediaEvent_EndpointAdded.new instead')
  static MediaEvent_EndpointAdded create() => MediaEvent_EndpointAdded._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_EndpointAdded._();
  @$core.override
  MediaEvent_EndpointAdded createEmptyInstance() =>
      MediaEvent_EndpointAdded._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_EndpointAdded getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_EndpointAdded>(
          MediaEvent_EndpointAdded.$_createMessage);
  static MediaEvent_EndpointAdded? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get metadataJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set metadataJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMetadataJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearMetadataJson() => $_clearField(2);
}

/// Sent to the peer after connecting to the WebRTC Endpoint.
class MediaEvent_Connected extends $pb.GeneratedMessage {
  factory MediaEvent_Connected({
    $core.String? endpointId,
    $core.Iterable<$core.MapEntry<$core.String, MediaEvent_Endpoint>>?
        endpointIdToEndpoint,
    $core.Iterable<MediaEvent_IceServer>? iceServers,
  }) {
    final result = MediaEvent_Connected._();
    if (endpointId != null) result.endpointId = endpointId;
    if (endpointIdToEndpoint != null)
      result.endpointIdToEndpoint.addEntries(endpointIdToEndpoint);
    if (iceServers != null) result.iceServers.addAll(iceServers);
    return result;
  }

  MediaEvent_Connected._();

  factory MediaEvent_Connected.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Connected()..mergeFromBuffer(data, registry);
  factory MediaEvent_Connected.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Connected()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.Connected',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_Connected.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..m<$core.String, MediaEvent_Endpoint>(
        2, _omitFieldNames ? '' : 'endpointIdToEndpoint',
        entryClassName: 'MediaEvent.Connected.EndpointIdToEndpointEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: MediaEvent_Endpoint.$_createMessage,
        valueDefaultOrMaker: MediaEvent_Endpoint.getDefault,
        packageName: const $pb.PackageName('fishjam.media_events.server'))
    ..pPM<MediaEvent_IceServer>(3, _omitFieldNames ? '' : 'iceServers',
        subBuilder: MediaEvent_IceServer.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Connected clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Connected copyWith(void Function(MediaEvent_Connected) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_Connected))
          as MediaEvent_Connected;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_Connected() / MediaEvent_Connected.new instead')
  static MediaEvent_Connected create() => MediaEvent_Connected._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_Connected._();
  @$core.override
  MediaEvent_Connected createEmptyInstance() => MediaEvent_Connected._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_Connected getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_Connected>(
          MediaEvent_Connected.$_createMessage);
  static MediaEvent_Connected? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, MediaEvent_Endpoint> get endpointIdToEndpoint =>
      $_getMap(1);

  @$pb.TagNumber(3)
  $pb.PbList<MediaEvent_IceServer> get iceServers => $_getList(2);
}

/// Sent to all remaining peers in the room after some endpoint was removed.
class MediaEvent_EndpointRemoved extends $pb.GeneratedMessage {
  factory MediaEvent_EndpointRemoved({
    $core.String? endpointId,
  }) {
    final result = MediaEvent_EndpointRemoved._();
    if (endpointId != null) result.endpointId = endpointId;
    return result;
  }

  MediaEvent_EndpointRemoved._();

  factory MediaEvent_EndpointRemoved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_EndpointRemoved()..mergeFromBuffer(data, registry);
  factory MediaEvent_EndpointRemoved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_EndpointRemoved()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.EndpointRemoved',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_EndpointRemoved.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_EndpointRemoved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_EndpointRemoved copyWith(
          void Function(MediaEvent_EndpointRemoved) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_EndpointRemoved))
          as MediaEvent_EndpointRemoved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_EndpointRemoved() / MediaEvent_EndpointRemoved.new instead')
  static MediaEvent_EndpointRemoved create() => MediaEvent_EndpointRemoved._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_EndpointRemoved._();
  @$core.override
  MediaEvent_EndpointRemoved createEmptyInstance() =>
      MediaEvent_EndpointRemoved._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_EndpointRemoved getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_EndpointRemoved>(
          MediaEvent_EndpointRemoved.$_createMessage);
  static MediaEvent_EndpointRemoved? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);
}

/// Sent to inform that an error occurred on the server providing a message to show
class MediaEvent_Error extends $pb.GeneratedMessage {
  factory MediaEvent_Error({
    $core.String? message,
  }) {
    final result = MediaEvent_Error._();
    if (message != null) result.message = message;
    return result;
  }

  MediaEvent_Error._();

  factory MediaEvent_Error.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Error()..mergeFromBuffer(data, registry);
  factory MediaEvent_Error.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Error()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.Error',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_Error.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Error clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Error copyWith(void Function(MediaEvent_Error) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_Error))
          as MediaEvent_Error;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MediaEvent_Error() / MediaEvent_Error.new instead')
  static MediaEvent_Error create() => MediaEvent_Error._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_Error._();
  @$core.override
  MediaEvent_Error createEmptyInstance() => MediaEvent_Error._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_Error getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MediaEvent_Error>(
          MediaEvent_Error.$_createMessage);
  static MediaEvent_Error? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
}

class MediaEvent_OfferData_TrackTypes extends $pb.GeneratedMessage {
  factory MediaEvent_OfferData_TrackTypes({
    $core.int? audio,
    $core.int? video,
  }) {
    final result = MediaEvent_OfferData_TrackTypes._();
    if (audio != null) result.audio = audio;
    if (video != null) result.video = video;
    return result;
  }

  MediaEvent_OfferData_TrackTypes._();

  factory MediaEvent_OfferData_TrackTypes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_OfferData_TrackTypes()..mergeFromBuffer(data, registry);
  factory MediaEvent_OfferData_TrackTypes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_OfferData_TrackTypes()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.OfferData.TrackTypes',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_OfferData_TrackTypes.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'audio')
    ..aI(2, _omitFieldNames ? '' : 'video')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_OfferData_TrackTypes clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_OfferData_TrackTypes copyWith(
          void Function(MediaEvent_OfferData_TrackTypes) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_OfferData_TrackTypes))
          as MediaEvent_OfferData_TrackTypes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_OfferData_TrackTypes() / MediaEvent_OfferData_TrackTypes.new instead')
  static MediaEvent_OfferData_TrackTypes create() =>
      MediaEvent_OfferData_TrackTypes._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_OfferData_TrackTypes._();
  @$core.override
  MediaEvent_OfferData_TrackTypes createEmptyInstance() =>
      MediaEvent_OfferData_TrackTypes._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_OfferData_TrackTypes getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_OfferData_TrackTypes>(
          MediaEvent_OfferData_TrackTypes.$_createMessage);
  static MediaEvent_OfferData_TrackTypes? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get audio => $_getIZ(0);
  @$pb.TagNumber(1)
  set audio($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAudio() => $_has(0);
  @$pb.TagNumber(1)
  void clearAudio() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get video => $_getIZ(1);
  @$pb.TagNumber(2)
  set video($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVideo() => $_has(1);
  @$pb.TagNumber(2)
  void clearVideo() => $_clearField(2);
}

/// Sent to inform about the number of audio and video tracks that will be sent from the engine to the peer
class MediaEvent_OfferData extends $pb.GeneratedMessage {
  factory MediaEvent_OfferData({
    MediaEvent_OfferData_TrackTypes? tracksTypes,
  }) {
    final result = MediaEvent_OfferData._();
    if (tracksTypes != null) result.tracksTypes = tracksTypes;
    return result;
  }

  MediaEvent_OfferData._();

  factory MediaEvent_OfferData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_OfferData()..mergeFromBuffer(data, registry);
  factory MediaEvent_OfferData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_OfferData()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.OfferData',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_OfferData.$_createMessage)
    ..aOM<MediaEvent_OfferData_TrackTypes>(
        1, _omitFieldNames ? '' : 'tracksTypes',
        subBuilder: MediaEvent_OfferData_TrackTypes.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_OfferData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_OfferData copyWith(void Function(MediaEvent_OfferData) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_OfferData))
          as MediaEvent_OfferData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_OfferData() / MediaEvent_OfferData.new instead')
  static MediaEvent_OfferData create() => MediaEvent_OfferData._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_OfferData._();
  @$core.override
  MediaEvent_OfferData createEmptyInstance() => MediaEvent_OfferData._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_OfferData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_OfferData>(
          MediaEvent_OfferData.$_createMessage);
  static MediaEvent_OfferData? _defaultInstance;

  @$pb.TagNumber(1)
  MediaEvent_OfferData_TrackTypes get tracksTypes => $_getN(0);
  @$pb.TagNumber(1)
  set tracksTypes(MediaEvent_OfferData_TrackTypes value) =>
      $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTracksTypes() => $_has(0);
  @$pb.TagNumber(1)
  void clearTracksTypes() => $_clearField(1);
  @$pb.TagNumber(1)
  MediaEvent_OfferData_TrackTypes ensureTracksTypes() => $_ensure(0);
}

/// Sent after receiving `SdpOffer` from Peer
class MediaEvent_SdpAnswer extends $pb.GeneratedMessage {
  factory MediaEvent_SdpAnswer({
    $core.String? sdp,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? midToTrackId,
  }) {
    final result = MediaEvent_SdpAnswer._();
    if (sdp != null) result.sdp = sdp;
    if (midToTrackId != null) result.midToTrackId.addEntries(midToTrackId);
    return result;
  }

  MediaEvent_SdpAnswer._();

  factory MediaEvent_SdpAnswer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_SdpAnswer()..mergeFromBuffer(data, registry);
  factory MediaEvent_SdpAnswer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_SdpAnswer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.SdpAnswer',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_SdpAnswer.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sdp')
    ..m<$core.String, $core.String>(2, _omitFieldNames ? '' : 'midToTrackId',
        entryClassName: 'MediaEvent.SdpAnswer.MidToTrackIdEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('fishjam.media_events.server'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_SdpAnswer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_SdpAnswer copyWith(void Function(MediaEvent_SdpAnswer) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_SdpAnswer))
          as MediaEvent_SdpAnswer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_SdpAnswer() / MediaEvent_SdpAnswer.new instead')
  static MediaEvent_SdpAnswer create() => MediaEvent_SdpAnswer._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_SdpAnswer._();
  @$core.override
  MediaEvent_SdpAnswer createEmptyInstance() => MediaEvent_SdpAnswer._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_SdpAnswer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_SdpAnswer>(
          MediaEvent_SdpAnswer.$_createMessage);
  static MediaEvent_SdpAnswer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sdp => $_getSZ(0);
  @$pb.TagNumber(1)
  set sdp($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSdp() => $_has(0);
  @$pb.TagNumber(1)
  void clearSdp() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $core.String> get midToTrackId => $_getMap(1);
}

/// Sent to inform that the track denoted by `trackId` has changed their voice activity
/// For this notification to work, the server must be configured to use VAD extension
/// and the sender must support it.
class MediaEvent_VadNotification extends $pb.GeneratedMessage {
  factory MediaEvent_VadNotification({
    $core.String? trackId,
    MediaEvent_VadNotification_Status? status,
  }) {
    final result = MediaEvent_VadNotification._();
    if (trackId != null) result.trackId = trackId;
    if (status != null) result.status = status;
    return result;
  }

  MediaEvent_VadNotification._();

  factory MediaEvent_VadNotification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_VadNotification()..mergeFromBuffer(data, registry);
  factory MediaEvent_VadNotification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_VadNotification()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.VadNotification',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_VadNotification.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'trackId')
    ..aE<MediaEvent_VadNotification_Status>(2, _omitFieldNames ? '' : 'status',
        enumValues: MediaEvent_VadNotification_Status.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_VadNotification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_VadNotification copyWith(
          void Function(MediaEvent_VadNotification) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_VadNotification))
          as MediaEvent_VadNotification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_VadNotification() / MediaEvent_VadNotification.new instead')
  static MediaEvent_VadNotification create() => MediaEvent_VadNotification._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_VadNotification._();
  @$core.override
  MediaEvent_VadNotification createEmptyInstance() =>
      MediaEvent_VadNotification._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_VadNotification getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_VadNotification>(
          MediaEvent_VadNotification.$_createMessage);
  static MediaEvent_VadNotification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get trackId => $_getSZ(0);
  @$pb.TagNumber(1)
  set trackId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);

  @$pb.TagNumber(2)
  MediaEvent_VadNotification_Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(MediaEvent_VadNotification_Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
}

/// Informs that track's variant has been changed
class MediaEvent_TrackVariantSwitched extends $pb.GeneratedMessage {
  factory MediaEvent_TrackVariantSwitched({
    $core.String? endpointId,
    $core.String? trackId,
    $0.Variant? variant,
  }) {
    final result = MediaEvent_TrackVariantSwitched._();
    if (endpointId != null) result.endpointId = endpointId;
    if (trackId != null) result.trackId = trackId;
    if (variant != null) result.variant = variant;
    return result;
  }

  MediaEvent_TrackVariantSwitched._();

  factory MediaEvent_TrackVariantSwitched.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackVariantSwitched()..mergeFromBuffer(data, registry);
  factory MediaEvent_TrackVariantSwitched.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackVariantSwitched()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.TrackVariantSwitched',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_TrackVariantSwitched.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..aOS(2, _omitFieldNames ? '' : 'trackId')
    ..aE<$0.Variant>(3, _omitFieldNames ? '' : 'variant',
        enumValues: $0.Variant.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackVariantSwitched clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackVariantSwitched copyWith(
          void Function(MediaEvent_TrackVariantSwitched) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_TrackVariantSwitched))
          as MediaEvent_TrackVariantSwitched;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_TrackVariantSwitched() / MediaEvent_TrackVariantSwitched.new instead')
  static MediaEvent_TrackVariantSwitched create() =>
      MediaEvent_TrackVariantSwitched._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_TrackVariantSwitched._();
  @$core.override
  MediaEvent_TrackVariantSwitched createEmptyInstance() =>
      MediaEvent_TrackVariantSwitched._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_TrackVariantSwitched getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_TrackVariantSwitched>(
          MediaEvent_TrackVariantSwitched.$_createMessage);
  static MediaEvent_TrackVariantSwitched? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get trackId => $_getSZ(1);
  @$pb.TagNumber(2)
  set trackId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTrackId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrackId() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Variant get variant => $_getN(2);
  @$pb.TagNumber(3)
  set variant($0.Variant value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasVariant() => $_has(2);
  @$pb.TagNumber(3)
  void clearVariant() => $_clearField(3);
}

/// Sent when track's variant has been disabled
class MediaEvent_TrackVariantDisabled extends $pb.GeneratedMessage {
  factory MediaEvent_TrackVariantDisabled({
    $core.String? endpointId,
    $core.String? trackId,
    $0.Variant? variant,
  }) {
    final result = MediaEvent_TrackVariantDisabled._();
    if (endpointId != null) result.endpointId = endpointId;
    if (trackId != null) result.trackId = trackId;
    if (variant != null) result.variant = variant;
    return result;
  }

  MediaEvent_TrackVariantDisabled._();

  factory MediaEvent_TrackVariantDisabled.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackVariantDisabled()..mergeFromBuffer(data, registry);
  factory MediaEvent_TrackVariantDisabled.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackVariantDisabled()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.TrackVariantDisabled',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_TrackVariantDisabled.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..aOS(2, _omitFieldNames ? '' : 'trackId')
    ..aE<$0.Variant>(3, _omitFieldNames ? '' : 'variant',
        enumValues: $0.Variant.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackVariantDisabled clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackVariantDisabled copyWith(
          void Function(MediaEvent_TrackVariantDisabled) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_TrackVariantDisabled))
          as MediaEvent_TrackVariantDisabled;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_TrackVariantDisabled() / MediaEvent_TrackVariantDisabled.new instead')
  static MediaEvent_TrackVariantDisabled create() =>
      MediaEvent_TrackVariantDisabled._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_TrackVariantDisabled._();
  @$core.override
  MediaEvent_TrackVariantDisabled createEmptyInstance() =>
      MediaEvent_TrackVariantDisabled._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_TrackVariantDisabled getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_TrackVariantDisabled>(
          MediaEvent_TrackVariantDisabled.$_createMessage);
  static MediaEvent_TrackVariantDisabled? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get trackId => $_getSZ(1);
  @$pb.TagNumber(2)
  set trackId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTrackId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrackId() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Variant get variant => $_getN(2);
  @$pb.TagNumber(3)
  set variant($0.Variant value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasVariant() => $_has(2);
  @$pb.TagNumber(3)
  void clearVariant() => $_clearField(3);
}

/// Sent when track's variant has been enabled
class MediaEvent_TrackVariantEnabled extends $pb.GeneratedMessage {
  factory MediaEvent_TrackVariantEnabled({
    $core.String? endpointId,
    $core.String? trackId,
    $0.Variant? variant,
  }) {
    final result = MediaEvent_TrackVariantEnabled._();
    if (endpointId != null) result.endpointId = endpointId;
    if (trackId != null) result.trackId = trackId;
    if (variant != null) result.variant = variant;
    return result;
  }

  MediaEvent_TrackVariantEnabled._();

  factory MediaEvent_TrackVariantEnabled.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackVariantEnabled()..mergeFromBuffer(data, registry);
  factory MediaEvent_TrackVariantEnabled.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackVariantEnabled()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.TrackVariantEnabled',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent_TrackVariantEnabled.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpointId')
    ..aOS(2, _omitFieldNames ? '' : 'trackId')
    ..aE<$0.Variant>(3, _omitFieldNames ? '' : 'variant',
        enumValues: $0.Variant.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackVariantEnabled clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackVariantEnabled copyWith(
          void Function(MediaEvent_TrackVariantEnabled) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_TrackVariantEnabled))
          as MediaEvent_TrackVariantEnabled;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_TrackVariantEnabled() / MediaEvent_TrackVariantEnabled.new instead')
  static MediaEvent_TrackVariantEnabled create() =>
      MediaEvent_TrackVariantEnabled._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_TrackVariantEnabled._();
  @$core.override
  MediaEvent_TrackVariantEnabled createEmptyInstance() =>
      MediaEvent_TrackVariantEnabled._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_TrackVariantEnabled getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_TrackVariantEnabled>(
          MediaEvent_TrackVariantEnabled.$_createMessage);
  static MediaEvent_TrackVariantEnabled? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpointId => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpointId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get trackId => $_getSZ(1);
  @$pb.TagNumber(2)
  set trackId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTrackId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrackId() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Variant get variant => $_getN(2);
  @$pb.TagNumber(3)
  set variant($0.Variant value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasVariant() => $_has(2);
  @$pb.TagNumber(3)
  void clearVariant() => $_clearField(3);
}

enum MediaEvent_Content {
  endpointUpdated,
  trackUpdated,
  tracksAdded,
  tracksRemoved,
  endpointAdded,
  endpointRemoved,
  connected,
  error,
  offerData,
  candidate,
  sdpAnswer,
  vadNotification,
  trackVariantSwitched,
  trackVariantDisabled,
  trackVariantEnabled,
  notSet
}

/// Defines any type of message sent from Membrane RTC Engine to Peer
class MediaEvent extends $pb.GeneratedMessage {
  factory MediaEvent({
    MediaEvent_EndpointUpdated? endpointUpdated,
    MediaEvent_TrackUpdated? trackUpdated,
    MediaEvent_TracksAdded? tracksAdded,
    MediaEvent_TracksRemoved? tracksRemoved,
    MediaEvent_EndpointAdded? endpointAdded,
    MediaEvent_EndpointRemoved? endpointRemoved,
    MediaEvent_Connected? connected,
    MediaEvent_Error? error,
    MediaEvent_OfferData? offerData,
    $0.Candidate? candidate,
    MediaEvent_SdpAnswer? sdpAnswer,
    MediaEvent_VadNotification? vadNotification,
    MediaEvent_TrackVariantSwitched? trackVariantSwitched,
    MediaEvent_TrackVariantDisabled? trackVariantDisabled,
    MediaEvent_TrackVariantEnabled? trackVariantEnabled,
  }) {
    final result = MediaEvent._();
    if (endpointUpdated != null) result.endpointUpdated = endpointUpdated;
    if (trackUpdated != null) result.trackUpdated = trackUpdated;
    if (tracksAdded != null) result.tracksAdded = tracksAdded;
    if (tracksRemoved != null) result.tracksRemoved = tracksRemoved;
    if (endpointAdded != null) result.endpointAdded = endpointAdded;
    if (endpointRemoved != null) result.endpointRemoved = endpointRemoved;
    if (connected != null) result.connected = connected;
    if (error != null) result.error = error;
    if (offerData != null) result.offerData = offerData;
    if (candidate != null) result.candidate = candidate;
    if (sdpAnswer != null) result.sdpAnswer = sdpAnswer;
    if (vadNotification != null) result.vadNotification = vadNotification;
    if (trackVariantSwitched != null)
      result.trackVariantSwitched = trackVariantSwitched;
    if (trackVariantDisabled != null)
      result.trackVariantDisabled = trackVariantDisabled;
    if (trackVariantEnabled != null)
      result.trackVariantEnabled = trackVariantEnabled;
    return result;
  }

  MediaEvent._();

  factory MediaEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent()..mergeFromBuffer(data, registry);
  factory MediaEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, MediaEvent_Content>
      _MediaEvent_ContentByTag = {
    1: MediaEvent_Content.endpointUpdated,
    2: MediaEvent_Content.trackUpdated,
    3: MediaEvent_Content.tracksAdded,
    4: MediaEvent_Content.tracksRemoved,
    5: MediaEvent_Content.endpointAdded,
    6: MediaEvent_Content.endpointRemoved,
    7: MediaEvent_Content.connected,
    8: MediaEvent_Content.error,
    9: MediaEvent_Content.offerData,
    10: MediaEvent_Content.candidate,
    11: MediaEvent_Content.sdpAnswer,
    12: MediaEvent_Content.vadNotification,
    13: MediaEvent_Content.trackVariantSwitched,
    14: MediaEvent_Content.trackVariantDisabled,
    15: MediaEvent_Content.trackVariantEnabled,
    0: MediaEvent_Content.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.server'),
      createEmptyInstance: MediaEvent.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
    ..aOM<MediaEvent_EndpointUpdated>(
        1, _omitFieldNames ? '' : 'endpointUpdated',
        subBuilder: MediaEvent_EndpointUpdated.$_createMessage)
    ..aOM<MediaEvent_TrackUpdated>(2, _omitFieldNames ? '' : 'trackUpdated',
        subBuilder: MediaEvent_TrackUpdated.$_createMessage)
    ..aOM<MediaEvent_TracksAdded>(3, _omitFieldNames ? '' : 'tracksAdded',
        subBuilder: MediaEvent_TracksAdded.$_createMessage)
    ..aOM<MediaEvent_TracksRemoved>(4, _omitFieldNames ? '' : 'tracksRemoved',
        subBuilder: MediaEvent_TracksRemoved.$_createMessage)
    ..aOM<MediaEvent_EndpointAdded>(5, _omitFieldNames ? '' : 'endpointAdded',
        subBuilder: MediaEvent_EndpointAdded.$_createMessage)
    ..aOM<MediaEvent_EndpointRemoved>(
        6, _omitFieldNames ? '' : 'endpointRemoved',
        subBuilder: MediaEvent_EndpointRemoved.$_createMessage)
    ..aOM<MediaEvent_Connected>(7, _omitFieldNames ? '' : 'connected',
        subBuilder: MediaEvent_Connected.$_createMessage)
    ..aOM<MediaEvent_Error>(8, _omitFieldNames ? '' : 'error',
        subBuilder: MediaEvent_Error.$_createMessage)
    ..aOM<MediaEvent_OfferData>(9, _omitFieldNames ? '' : 'offerData',
        subBuilder: MediaEvent_OfferData.$_createMessage)
    ..aOM<$0.Candidate>(10, _omitFieldNames ? '' : 'candidate',
        subBuilder: $0.Candidate.$_createMessage)
    ..aOM<MediaEvent_SdpAnswer>(11, _omitFieldNames ? '' : 'sdpAnswer',
        subBuilder: MediaEvent_SdpAnswer.$_createMessage)
    ..aOM<MediaEvent_VadNotification>(
        12, _omitFieldNames ? '' : 'vadNotification',
        subBuilder: MediaEvent_VadNotification.$_createMessage)
    ..aOM<MediaEvent_TrackVariantSwitched>(
        13, _omitFieldNames ? '' : 'trackVariantSwitched',
        subBuilder: MediaEvent_TrackVariantSwitched.$_createMessage)
    ..aOM<MediaEvent_TrackVariantDisabled>(
        14, _omitFieldNames ? '' : 'trackVariantDisabled',
        subBuilder: MediaEvent_TrackVariantDisabled.$_createMessage)
    ..aOM<MediaEvent_TrackVariantEnabled>(
        15, _omitFieldNames ? '' : 'trackVariantEnabled',
        subBuilder: MediaEvent_TrackVariantEnabled.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent copyWith(void Function(MediaEvent) updates) =>
      super.copyWith((message) => updates(message as MediaEvent)) as MediaEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MediaEvent() / MediaEvent.new instead')
  static MediaEvent create() => MediaEvent._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent._();
  @$core.override
  MediaEvent createEmptyInstance() => MediaEvent._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent>(MediaEvent.$_createMessage);
  static MediaEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  MediaEvent_Content whichContent() =>
      _MediaEvent_ContentByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  void clearContent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  MediaEvent_EndpointUpdated get endpointUpdated => $_getN(0);
  @$pb.TagNumber(1)
  set endpointUpdated(MediaEvent_EndpointUpdated value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpointUpdated() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpointUpdated() => $_clearField(1);
  @$pb.TagNumber(1)
  MediaEvent_EndpointUpdated ensureEndpointUpdated() => $_ensure(0);

  @$pb.TagNumber(2)
  MediaEvent_TrackUpdated get trackUpdated => $_getN(1);
  @$pb.TagNumber(2)
  set trackUpdated(MediaEvent_TrackUpdated value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTrackUpdated() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrackUpdated() => $_clearField(2);
  @$pb.TagNumber(2)
  MediaEvent_TrackUpdated ensureTrackUpdated() => $_ensure(1);

  @$pb.TagNumber(3)
  MediaEvent_TracksAdded get tracksAdded => $_getN(2);
  @$pb.TagNumber(3)
  set tracksAdded(MediaEvent_TracksAdded value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasTracksAdded() => $_has(2);
  @$pb.TagNumber(3)
  void clearTracksAdded() => $_clearField(3);
  @$pb.TagNumber(3)
  MediaEvent_TracksAdded ensureTracksAdded() => $_ensure(2);

  @$pb.TagNumber(4)
  MediaEvent_TracksRemoved get tracksRemoved => $_getN(3);
  @$pb.TagNumber(4)
  set tracksRemoved(MediaEvent_TracksRemoved value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTracksRemoved() => $_has(3);
  @$pb.TagNumber(4)
  void clearTracksRemoved() => $_clearField(4);
  @$pb.TagNumber(4)
  MediaEvent_TracksRemoved ensureTracksRemoved() => $_ensure(3);

  @$pb.TagNumber(5)
  MediaEvent_EndpointAdded get endpointAdded => $_getN(4);
  @$pb.TagNumber(5)
  set endpointAdded(MediaEvent_EndpointAdded value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEndpointAdded() => $_has(4);
  @$pb.TagNumber(5)
  void clearEndpointAdded() => $_clearField(5);
  @$pb.TagNumber(5)
  MediaEvent_EndpointAdded ensureEndpointAdded() => $_ensure(4);

  @$pb.TagNumber(6)
  MediaEvent_EndpointRemoved get endpointRemoved => $_getN(5);
  @$pb.TagNumber(6)
  set endpointRemoved(MediaEvent_EndpointRemoved value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasEndpointRemoved() => $_has(5);
  @$pb.TagNumber(6)
  void clearEndpointRemoved() => $_clearField(6);
  @$pb.TagNumber(6)
  MediaEvent_EndpointRemoved ensureEndpointRemoved() => $_ensure(5);

  @$pb.TagNumber(7)
  MediaEvent_Connected get connected => $_getN(6);
  @$pb.TagNumber(7)
  set connected(MediaEvent_Connected value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasConnected() => $_has(6);
  @$pb.TagNumber(7)
  void clearConnected() => $_clearField(7);
  @$pb.TagNumber(7)
  MediaEvent_Connected ensureConnected() => $_ensure(6);

  @$pb.TagNumber(8)
  MediaEvent_Error get error => $_getN(7);
  @$pb.TagNumber(8)
  set error(MediaEvent_Error value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasError() => $_has(7);
  @$pb.TagNumber(8)
  void clearError() => $_clearField(8);
  @$pb.TagNumber(8)
  MediaEvent_Error ensureError() => $_ensure(7);

  @$pb.TagNumber(9)
  MediaEvent_OfferData get offerData => $_getN(8);
  @$pb.TagNumber(9)
  set offerData(MediaEvent_OfferData value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasOfferData() => $_has(8);
  @$pb.TagNumber(9)
  void clearOfferData() => $_clearField(9);
  @$pb.TagNumber(9)
  MediaEvent_OfferData ensureOfferData() => $_ensure(8);

  @$pb.TagNumber(10)
  $0.Candidate get candidate => $_getN(9);
  @$pb.TagNumber(10)
  set candidate($0.Candidate value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasCandidate() => $_has(9);
  @$pb.TagNumber(10)
  void clearCandidate() => $_clearField(10);
  @$pb.TagNumber(10)
  $0.Candidate ensureCandidate() => $_ensure(9);

  @$pb.TagNumber(11)
  MediaEvent_SdpAnswer get sdpAnswer => $_getN(10);
  @$pb.TagNumber(11)
  set sdpAnswer(MediaEvent_SdpAnswer value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSdpAnswer() => $_has(10);
  @$pb.TagNumber(11)
  void clearSdpAnswer() => $_clearField(11);
  @$pb.TagNumber(11)
  MediaEvent_SdpAnswer ensureSdpAnswer() => $_ensure(10);

  @$pb.TagNumber(12)
  MediaEvent_VadNotification get vadNotification => $_getN(11);
  @$pb.TagNumber(12)
  set vadNotification(MediaEvent_VadNotification value) =>
      $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasVadNotification() => $_has(11);
  @$pb.TagNumber(12)
  void clearVadNotification() => $_clearField(12);
  @$pb.TagNumber(12)
  MediaEvent_VadNotification ensureVadNotification() => $_ensure(11);

  @$pb.TagNumber(13)
  MediaEvent_TrackVariantSwitched get trackVariantSwitched => $_getN(12);
  @$pb.TagNumber(13)
  set trackVariantSwitched(MediaEvent_TrackVariantSwitched value) =>
      $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasTrackVariantSwitched() => $_has(12);
  @$pb.TagNumber(13)
  void clearTrackVariantSwitched() => $_clearField(13);
  @$pb.TagNumber(13)
  MediaEvent_TrackVariantSwitched ensureTrackVariantSwitched() => $_ensure(12);

  @$pb.TagNumber(14)
  MediaEvent_TrackVariantDisabled get trackVariantDisabled => $_getN(13);
  @$pb.TagNumber(14)
  set trackVariantDisabled(MediaEvent_TrackVariantDisabled value) =>
      $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasTrackVariantDisabled() => $_has(13);
  @$pb.TagNumber(14)
  void clearTrackVariantDisabled() => $_clearField(14);
  @$pb.TagNumber(14)
  MediaEvent_TrackVariantDisabled ensureTrackVariantDisabled() => $_ensure(13);

  @$pb.TagNumber(15)
  MediaEvent_TrackVariantEnabled get trackVariantEnabled => $_getN(14);
  @$pb.TagNumber(15)
  set trackVariantEnabled(MediaEvent_TrackVariantEnabled value) =>
      $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasTrackVariantEnabled() => $_has(14);
  @$pb.TagNumber(15)
  void clearTrackVariantEnabled() => $_clearField(15);
  @$pb.TagNumber(15)
  MediaEvent_TrackVariantEnabled ensureTrackVariantEnabled() => $_ensure(14);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
