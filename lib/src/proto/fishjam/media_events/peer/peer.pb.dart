// This is a generated file - do not edit.
//
// Generated from fishjam/media_events/peer/peer.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../shared.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class MediaEvent_VariantBitrate extends $pb.GeneratedMessage {
  factory MediaEvent_VariantBitrate({
    $0.Variant? variant,
    $core.int? bitrate,
  }) {
    final result = MediaEvent_VariantBitrate._();
    if (variant != null) result.variant = variant;
    if (bitrate != null) result.bitrate = bitrate;
    return result;
  }

  MediaEvent_VariantBitrate._();

  factory MediaEvent_VariantBitrate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_VariantBitrate()..mergeFromBuffer(data, registry);
  factory MediaEvent_VariantBitrate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_VariantBitrate()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.VariantBitrate',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_VariantBitrate.$_createMessage)
    ..aE<$0.Variant>(1, _omitFieldNames ? '' : 'variant',
        enumValues: $0.Variant.values)
    ..aI(2, _omitFieldNames ? '' : 'bitrate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_VariantBitrate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_VariantBitrate copyWith(
          void Function(MediaEvent_VariantBitrate) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_VariantBitrate))
          as MediaEvent_VariantBitrate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_VariantBitrate() / MediaEvent_VariantBitrate.new instead')
  static MediaEvent_VariantBitrate create() => MediaEvent_VariantBitrate._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_VariantBitrate._();
  @$core.override
  MediaEvent_VariantBitrate createEmptyInstance() =>
      MediaEvent_VariantBitrate._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_VariantBitrate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_VariantBitrate>(
          MediaEvent_VariantBitrate.$_createMessage);
  static MediaEvent_VariantBitrate? _defaultInstance;

  @$pb.TagNumber(1)
  $0.Variant get variant => $_getN(0);
  @$pb.TagNumber(1)
  set variant($0.Variant value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVariant() => $_has(0);
  @$pb.TagNumber(1)
  void clearVariant() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get bitrate => $_getIZ(1);
  @$pb.TagNumber(2)
  set bitrate($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBitrate() => $_has(1);
  @$pb.TagNumber(2)
  void clearBitrate() => $_clearField(2);
}

/// Sent when a peer wants to join WebRTC Endpoint.
class MediaEvent_Connect extends $pb.GeneratedMessage {
  factory MediaEvent_Connect({
    $core.String? metadataJson,
  }) {
    final result = MediaEvent_Connect._();
    if (metadataJson != null) result.metadataJson = metadataJson;
    return result;
  }

  MediaEvent_Connect._();

  factory MediaEvent_Connect.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Connect()..mergeFromBuffer(data, registry);
  factory MediaEvent_Connect.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Connect()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.Connect',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_Connect.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'metadataJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Connect clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Connect copyWith(void Function(MediaEvent_Connect) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_Connect))
          as MediaEvent_Connect;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MediaEvent_Connect() / MediaEvent_Connect.new instead')
  static MediaEvent_Connect create() => MediaEvent_Connect._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_Connect._();
  @$core.override
  MediaEvent_Connect createEmptyInstance() => MediaEvent_Connect._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_Connect getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_Connect>(
          MediaEvent_Connect.$_createMessage);
  static MediaEvent_Connect? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get metadataJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set metadataJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMetadataJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearMetadataJson() => $_clearField(1);
}

/// Sent when a peer disconnects from WebRTC Endpoint.
class MediaEvent_Disconnect extends $pb.GeneratedMessage {
  factory MediaEvent_Disconnect() => MediaEvent_Disconnect._();

  MediaEvent_Disconnect._();

  factory MediaEvent_Disconnect.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Disconnect()..mergeFromBuffer(data, registry);
  factory MediaEvent_Disconnect.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_Disconnect()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.Disconnect',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_Disconnect.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Disconnect clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_Disconnect copyWith(
          void Function(MediaEvent_Disconnect) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_Disconnect))
          as MediaEvent_Disconnect;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_Disconnect() / MediaEvent_Disconnect.new instead')
  static MediaEvent_Disconnect create() => MediaEvent_Disconnect._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_Disconnect._();
  @$core.override
  MediaEvent_Disconnect createEmptyInstance() => MediaEvent_Disconnect._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_Disconnect getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_Disconnect>(
          MediaEvent_Disconnect.$_createMessage);
  static MediaEvent_Disconnect? _defaultInstance;
}

/// Sent when a peer wants to update its metadata
class MediaEvent_UpdateEndpointMetadata extends $pb.GeneratedMessage {
  factory MediaEvent_UpdateEndpointMetadata({
    $core.String? metadataJson,
  }) {
    final result = MediaEvent_UpdateEndpointMetadata._();
    if (metadataJson != null) result.metadataJson = metadataJson;
    return result;
  }

  MediaEvent_UpdateEndpointMetadata._();

  factory MediaEvent_UpdateEndpointMetadata.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_UpdateEndpointMetadata()..mergeFromBuffer(data, registry);
  factory MediaEvent_UpdateEndpointMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_UpdateEndpointMetadata()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.UpdateEndpointMetadata',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_UpdateEndpointMetadata.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'metadataJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_UpdateEndpointMetadata clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_UpdateEndpointMetadata copyWith(
          void Function(MediaEvent_UpdateEndpointMetadata) updates) =>
      super.copyWith((message) =>
              updates(message as MediaEvent_UpdateEndpointMetadata))
          as MediaEvent_UpdateEndpointMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_UpdateEndpointMetadata() / MediaEvent_UpdateEndpointMetadata.new instead')
  static MediaEvent_UpdateEndpointMetadata create() =>
      MediaEvent_UpdateEndpointMetadata._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_UpdateEndpointMetadata._();
  @$core.override
  MediaEvent_UpdateEndpointMetadata createEmptyInstance() =>
      MediaEvent_UpdateEndpointMetadata._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_UpdateEndpointMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_UpdateEndpointMetadata>(
          MediaEvent_UpdateEndpointMetadata.$_createMessage);
  static MediaEvent_UpdateEndpointMetadata? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get metadataJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set metadataJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMetadataJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearMetadataJson() => $_clearField(1);
}

/// Sent when a peer wants to update its track's metadata
class MediaEvent_UpdateTrackMetadata extends $pb.GeneratedMessage {
  factory MediaEvent_UpdateTrackMetadata({
    $core.String? trackId,
    $core.String? metadataJson,
  }) {
    final result = MediaEvent_UpdateTrackMetadata._();
    if (trackId != null) result.trackId = trackId;
    if (metadataJson != null) result.metadataJson = metadataJson;
    return result;
  }

  MediaEvent_UpdateTrackMetadata._();

  factory MediaEvent_UpdateTrackMetadata.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_UpdateTrackMetadata()..mergeFromBuffer(data, registry);
  factory MediaEvent_UpdateTrackMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_UpdateTrackMetadata()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.UpdateTrackMetadata',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_UpdateTrackMetadata.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'trackId')
    ..aOS(2, _omitFieldNames ? '' : 'metadataJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_UpdateTrackMetadata clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_UpdateTrackMetadata copyWith(
          void Function(MediaEvent_UpdateTrackMetadata) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_UpdateTrackMetadata))
          as MediaEvent_UpdateTrackMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_UpdateTrackMetadata() / MediaEvent_UpdateTrackMetadata.new instead')
  static MediaEvent_UpdateTrackMetadata create() =>
      MediaEvent_UpdateTrackMetadata._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_UpdateTrackMetadata._();
  @$core.override
  MediaEvent_UpdateTrackMetadata createEmptyInstance() =>
      MediaEvent_UpdateTrackMetadata._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_UpdateTrackMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_UpdateTrackMetadata>(
          MediaEvent_UpdateTrackMetadata.$_createMessage);
  static MediaEvent_UpdateTrackMetadata? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get trackId => $_getSZ(0);
  @$pb.TagNumber(1)
  set trackId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get metadataJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set metadataJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMetadataJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearMetadataJson() => $_clearField(2);
}

/// Sent when peer wants to renegotiate connection due to adding a track or removing a track
class MediaEvent_RenegotiateTracks extends $pb.GeneratedMessage {
  factory MediaEvent_RenegotiateTracks() => MediaEvent_RenegotiateTracks._();

  MediaEvent_RenegotiateTracks._();

  factory MediaEvent_RenegotiateTracks.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_RenegotiateTracks()..mergeFromBuffer(data, registry);
  factory MediaEvent_RenegotiateTracks.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_RenegotiateTracks()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.RenegotiateTracks',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_RenegotiateTracks.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_RenegotiateTracks clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_RenegotiateTracks copyWith(
          void Function(MediaEvent_RenegotiateTracks) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_RenegotiateTracks))
          as MediaEvent_RenegotiateTracks;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_RenegotiateTracks() / MediaEvent_RenegotiateTracks.new instead')
  static MediaEvent_RenegotiateTracks create() =>
      MediaEvent_RenegotiateTracks._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_RenegotiateTracks._();
  @$core.override
  MediaEvent_RenegotiateTracks createEmptyInstance() =>
      MediaEvent_RenegotiateTracks._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_RenegotiateTracks getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_RenegotiateTracks>(
          MediaEvent_RenegotiateTracks.$_createMessage);
  static MediaEvent_RenegotiateTracks? _defaultInstance;
}

/// Sent as a response to `offerData` media event during renegotiation
/// Maps contain only information about current peer's `sendonly` tracks.
/// The "mid" is an identifier used to associate an RTP packet with an MLine from the SDP offer/answer.
class MediaEvent_SdpOffer extends $pb.GeneratedMessage {
  factory MediaEvent_SdpOffer({
    $core.String? sdp,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        trackIdToMetadataJson,
    $core.Iterable<$core.MapEntry<$core.String, MediaEvent_TrackBitrates>>?
        trackIdToBitrates,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? midToTrackId,
  }) {
    final result = MediaEvent_SdpOffer._();
    if (sdp != null) result.sdp = sdp;
    if (trackIdToMetadataJson != null)
      result.trackIdToMetadataJson.addEntries(trackIdToMetadataJson);
    if (trackIdToBitrates != null)
      result.trackIdToBitrates.addEntries(trackIdToBitrates);
    if (midToTrackId != null) result.midToTrackId.addEntries(midToTrackId);
    return result;
  }

  MediaEvent_SdpOffer._();

  factory MediaEvent_SdpOffer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_SdpOffer()..mergeFromBuffer(data, registry);
  factory MediaEvent_SdpOffer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_SdpOffer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.SdpOffer',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_SdpOffer.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sdp')
    ..m<$core.String, $core.String>(
        2, _omitFieldNames ? '' : 'trackIdToMetadataJson',
        entryClassName: 'MediaEvent.SdpOffer.TrackIdToMetadataJsonEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('fishjam.media_events.peer'))
    ..m<$core.String, MediaEvent_TrackBitrates>(
        3, _omitFieldNames ? '' : 'trackIdToBitrates',
        entryClassName: 'MediaEvent.SdpOffer.TrackIdToBitratesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: MediaEvent_TrackBitrates.$_createMessage,
        valueDefaultOrMaker: MediaEvent_TrackBitrates.getDefault,
        packageName: const $pb.PackageName('fishjam.media_events.peer'))
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'midToTrackId',
        entryClassName: 'MediaEvent.SdpOffer.MidToTrackIdEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('fishjam.media_events.peer'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_SdpOffer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_SdpOffer copyWith(void Function(MediaEvent_SdpOffer) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_SdpOffer))
          as MediaEvent_SdpOffer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use MediaEvent_SdpOffer() / MediaEvent_SdpOffer.new instead')
  static MediaEvent_SdpOffer create() => MediaEvent_SdpOffer._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_SdpOffer._();
  @$core.override
  MediaEvent_SdpOffer createEmptyInstance() => MediaEvent_SdpOffer._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_SdpOffer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_SdpOffer>(
          MediaEvent_SdpOffer.$_createMessage);
  static MediaEvent_SdpOffer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sdp => $_getSZ(0);
  @$pb.TagNumber(1)
  set sdp($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSdp() => $_has(0);
  @$pb.TagNumber(1)
  void clearSdp() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $core.String> get trackIdToMetadataJson =>
      $_getMap(1);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, MediaEvent_TrackBitrates> get trackIdToBitrates =>
      $_getMap(2);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get midToTrackId => $_getMap(3);
}

/// Sent when Peer wants to update its track's bitrate
class MediaEvent_TrackBitrates extends $pb.GeneratedMessage {
  factory MediaEvent_TrackBitrates({
    $core.String? trackId,
    $core.Iterable<MediaEvent_VariantBitrate>? variantBitrates,
  }) {
    final result = MediaEvent_TrackBitrates._();
    if (trackId != null) result.trackId = trackId;
    if (variantBitrates != null) result.variantBitrates.addAll(variantBitrates);
    return result;
  }

  MediaEvent_TrackBitrates._();

  factory MediaEvent_TrackBitrates.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackBitrates()..mergeFromBuffer(data, registry);
  factory MediaEvent_TrackBitrates.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_TrackBitrates()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.TrackBitrates',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_TrackBitrates.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'trackId')
    ..pPM<MediaEvent_VariantBitrate>(
        2, _omitFieldNames ? '' : 'variantBitrates',
        subBuilder: MediaEvent_VariantBitrate.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackBitrates clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_TrackBitrates copyWith(
          void Function(MediaEvent_TrackBitrates) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_TrackBitrates))
          as MediaEvent_TrackBitrates;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_TrackBitrates() / MediaEvent_TrackBitrates.new instead')
  static MediaEvent_TrackBitrates create() => MediaEvent_TrackBitrates._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_TrackBitrates._();
  @$core.override
  MediaEvent_TrackBitrates createEmptyInstance() =>
      MediaEvent_TrackBitrates._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_TrackBitrates getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_TrackBitrates>(
          MediaEvent_TrackBitrates.$_createMessage);
  static MediaEvent_TrackBitrates? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get trackId => $_getSZ(0);
  @$pb.TagNumber(1)
  set trackId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<MediaEvent_VariantBitrate> get variantBitrates => $_getList(1);
}

/// Sent when client disables one of the track variants
class MediaEvent_DisableTrackVariant extends $pb.GeneratedMessage {
  factory MediaEvent_DisableTrackVariant({
    $core.String? trackId,
    $0.Variant? variant,
  }) {
    final result = MediaEvent_DisableTrackVariant._();
    if (trackId != null) result.trackId = trackId;
    if (variant != null) result.variant = variant;
    return result;
  }

  MediaEvent_DisableTrackVariant._();

  factory MediaEvent_DisableTrackVariant.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_DisableTrackVariant()..mergeFromBuffer(data, registry);
  factory MediaEvent_DisableTrackVariant.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_DisableTrackVariant()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.DisableTrackVariant',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_DisableTrackVariant.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'trackId')
    ..aE<$0.Variant>(2, _omitFieldNames ? '' : 'variant',
        enumValues: $0.Variant.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_DisableTrackVariant clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_DisableTrackVariant copyWith(
          void Function(MediaEvent_DisableTrackVariant) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_DisableTrackVariant))
          as MediaEvent_DisableTrackVariant;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_DisableTrackVariant() / MediaEvent_DisableTrackVariant.new instead')
  static MediaEvent_DisableTrackVariant create() =>
      MediaEvent_DisableTrackVariant._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_DisableTrackVariant._();
  @$core.override
  MediaEvent_DisableTrackVariant createEmptyInstance() =>
      MediaEvent_DisableTrackVariant._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_DisableTrackVariant getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_DisableTrackVariant>(
          MediaEvent_DisableTrackVariant.$_createMessage);
  static MediaEvent_DisableTrackVariant? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get trackId => $_getSZ(0);
  @$pb.TagNumber(1)
  set trackId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.Variant get variant => $_getN(1);
  @$pb.TagNumber(2)
  set variant($0.Variant value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasVariant() => $_has(1);
  @$pb.TagNumber(2)
  void clearVariant() => $_clearField(2);
}

/// Sent when client enables one of the track variants
class MediaEvent_EnableTrackVariant extends $pb.GeneratedMessage {
  factory MediaEvent_EnableTrackVariant({
    $core.String? trackId,
    $0.Variant? variant,
  }) {
    final result = MediaEvent_EnableTrackVariant._();
    if (trackId != null) result.trackId = trackId;
    if (variant != null) result.variant = variant;
    return result;
  }

  MediaEvent_EnableTrackVariant._();

  factory MediaEvent_EnableTrackVariant.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_EnableTrackVariant()..mergeFromBuffer(data, registry);
  factory MediaEvent_EnableTrackVariant.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_EnableTrackVariant()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.EnableTrackVariant',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_EnableTrackVariant.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'trackId')
    ..aE<$0.Variant>(2, _omitFieldNames ? '' : 'variant',
        enumValues: $0.Variant.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_EnableTrackVariant clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_EnableTrackVariant copyWith(
          void Function(MediaEvent_EnableTrackVariant) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_EnableTrackVariant))
          as MediaEvent_EnableTrackVariant;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_EnableTrackVariant() / MediaEvent_EnableTrackVariant.new instead')
  static MediaEvent_EnableTrackVariant create() =>
      MediaEvent_EnableTrackVariant._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_EnableTrackVariant._();
  @$core.override
  MediaEvent_EnableTrackVariant createEmptyInstance() =>
      MediaEvent_EnableTrackVariant._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_EnableTrackVariant getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_EnableTrackVariant>(
          MediaEvent_EnableTrackVariant.$_createMessage);
  static MediaEvent_EnableTrackVariant? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get trackId => $_getSZ(0);
  @$pb.TagNumber(1)
  set trackId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.Variant get variant => $_getN(1);
  @$pb.TagNumber(2)
  set variant($0.Variant value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasVariant() => $_has(1);
  @$pb.TagNumber(2)
  void clearVariant() => $_clearField(2);
}

class MediaEvent_SetTargetTrackVariant extends $pb.GeneratedMessage {
  factory MediaEvent_SetTargetTrackVariant({
    $core.String? trackId,
    $0.Variant? variant,
  }) {
    final result = MediaEvent_SetTargetTrackVariant._();
    if (trackId != null) result.trackId = trackId;
    if (variant != null) result.variant = variant;
    return result;
  }

  MediaEvent_SetTargetTrackVariant._();

  factory MediaEvent_SetTargetTrackVariant.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_SetTargetTrackVariant()..mergeFromBuffer(data, registry);
  factory MediaEvent_SetTargetTrackVariant.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_SetTargetTrackVariant()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.SetTargetTrackVariant',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_SetTargetTrackVariant.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'trackId')
    ..aE<$0.Variant>(2, _omitFieldNames ? '' : 'variant',
        enumValues: $0.Variant.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_SetTargetTrackVariant clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_SetTargetTrackVariant copyWith(
          void Function(MediaEvent_SetTargetTrackVariant) updates) =>
      super.copyWith(
              (message) => updates(message as MediaEvent_SetTargetTrackVariant))
          as MediaEvent_SetTargetTrackVariant;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_SetTargetTrackVariant() / MediaEvent_SetTargetTrackVariant.new instead')
  static MediaEvent_SetTargetTrackVariant create() =>
      MediaEvent_SetTargetTrackVariant._();
  static $pb.GeneratedMessage $_createMessage() =>
      MediaEvent_SetTargetTrackVariant._();
  @$core.override
  MediaEvent_SetTargetTrackVariant createEmptyInstance() =>
      MediaEvent_SetTargetTrackVariant._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_SetTargetTrackVariant getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_SetTargetTrackVariant>(
          MediaEvent_SetTargetTrackVariant.$_createMessage);
  static MediaEvent_SetTargetTrackVariant? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get trackId => $_getSZ(0);
  @$pb.TagNumber(1)
  set trackId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.Variant get variant => $_getN(1);
  @$pb.TagNumber(2)
  set variant($0.Variant value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasVariant() => $_has(1);
  @$pb.TagNumber(2)
  void clearVariant() => $_clearField(2);
}

class MediaEvent_UnmuteTrack extends $pb.GeneratedMessage {
  factory MediaEvent_UnmuteTrack({
    $core.String? trackId,
  }) {
    final result = MediaEvent_UnmuteTrack._();
    if (trackId != null) result.trackId = trackId;
    return result;
  }

  MediaEvent_UnmuteTrack._();

  factory MediaEvent_UnmuteTrack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_UnmuteTrack()..mergeFromBuffer(data, registry);
  factory MediaEvent_UnmuteTrack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaEvent_UnmuteTrack()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent.UnmuteTrack',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent_UnmuteTrack.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'trackId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_UnmuteTrack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaEvent_UnmuteTrack copyWith(
          void Function(MediaEvent_UnmuteTrack) updates) =>
      super.copyWith((message) => updates(message as MediaEvent_UnmuteTrack))
          as MediaEvent_UnmuteTrack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use MediaEvent_UnmuteTrack() / MediaEvent_UnmuteTrack.new instead')
  static MediaEvent_UnmuteTrack create() => MediaEvent_UnmuteTrack._();
  static $pb.GeneratedMessage $_createMessage() => MediaEvent_UnmuteTrack._();
  @$core.override
  MediaEvent_UnmuteTrack createEmptyInstance() => MediaEvent_UnmuteTrack._();
  @$core.pragma('dart2js:noInline')
  static MediaEvent_UnmuteTrack getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaEvent_UnmuteTrack>(
          MediaEvent_UnmuteTrack.$_createMessage);
  static MediaEvent_UnmuteTrack? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get trackId => $_getSZ(0);
  @$pb.TagNumber(1)
  set trackId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);
}

enum MediaEvent_Content {
  connect,
  disconnect,
  updateEndpointMetadata,
  updateTrackMetadata,
  renegotiateTracks,
  candidate,
  sdpOffer,
  trackBitrates,
  enableTrackVariant,
  disableTrackVariant,
  setTargetTrackVariant,
  unmuteTrack,
  notSet
}

/// Defines any type of message sent from Peer to Membrane RTC Engine
class MediaEvent extends $pb.GeneratedMessage {
  factory MediaEvent({
    MediaEvent_Connect? connect,
    MediaEvent_Disconnect? disconnect,
    MediaEvent_UpdateEndpointMetadata? updateEndpointMetadata,
    MediaEvent_UpdateTrackMetadata? updateTrackMetadata,
    MediaEvent_RenegotiateTracks? renegotiateTracks,
    $0.Candidate? candidate,
    MediaEvent_SdpOffer? sdpOffer,
    MediaEvent_TrackBitrates? trackBitrates,
    MediaEvent_EnableTrackVariant? enableTrackVariant,
    MediaEvent_DisableTrackVariant? disableTrackVariant,
    MediaEvent_SetTargetTrackVariant? setTargetTrackVariant,
    MediaEvent_UnmuteTrack? unmuteTrack,
  }) {
    final result = MediaEvent._();
    if (connect != null) result.connect = connect;
    if (disconnect != null) result.disconnect = disconnect;
    if (updateEndpointMetadata != null)
      result.updateEndpointMetadata = updateEndpointMetadata;
    if (updateTrackMetadata != null)
      result.updateTrackMetadata = updateTrackMetadata;
    if (renegotiateTracks != null) result.renegotiateTracks = renegotiateTracks;
    if (candidate != null) result.candidate = candidate;
    if (sdpOffer != null) result.sdpOffer = sdpOffer;
    if (trackBitrates != null) result.trackBitrates = trackBitrates;
    if (enableTrackVariant != null)
      result.enableTrackVariant = enableTrackVariant;
    if (disableTrackVariant != null)
      result.disableTrackVariant = disableTrackVariant;
    if (setTargetTrackVariant != null)
      result.setTargetTrackVariant = setTargetTrackVariant;
    if (unmuteTrack != null) result.unmuteTrack = unmuteTrack;
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
    1: MediaEvent_Content.connect,
    2: MediaEvent_Content.disconnect,
    3: MediaEvent_Content.updateEndpointMetadata,
    4: MediaEvent_Content.updateTrackMetadata,
    5: MediaEvent_Content.renegotiateTracks,
    6: MediaEvent_Content.candidate,
    7: MediaEvent_Content.sdpOffer,
    8: MediaEvent_Content.trackBitrates,
    9: MediaEvent_Content.enableTrackVariant,
    10: MediaEvent_Content.disableTrackVariant,
    11: MediaEvent_Content.setTargetTrackVariant,
    12: MediaEvent_Content.unmuteTrack,
    0: MediaEvent_Content.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaEvent',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'fishjam.media_events.peer'),
      createEmptyInstance: MediaEvent.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
    ..aOM<MediaEvent_Connect>(1, _omitFieldNames ? '' : 'connect',
        subBuilder: MediaEvent_Connect.$_createMessage)
    ..aOM<MediaEvent_Disconnect>(2, _omitFieldNames ? '' : 'disconnect',
        subBuilder: MediaEvent_Disconnect.$_createMessage)
    ..aOM<MediaEvent_UpdateEndpointMetadata>(
        3, _omitFieldNames ? '' : 'updateEndpointMetadata',
        subBuilder: MediaEvent_UpdateEndpointMetadata.$_createMessage)
    ..aOM<MediaEvent_UpdateTrackMetadata>(
        4, _omitFieldNames ? '' : 'updateTrackMetadata',
        subBuilder: MediaEvent_UpdateTrackMetadata.$_createMessage)
    ..aOM<MediaEvent_RenegotiateTracks>(
        5, _omitFieldNames ? '' : 'renegotiateTracks',
        subBuilder: MediaEvent_RenegotiateTracks.$_createMessage)
    ..aOM<$0.Candidate>(6, _omitFieldNames ? '' : 'candidate',
        subBuilder: $0.Candidate.$_createMessage)
    ..aOM<MediaEvent_SdpOffer>(7, _omitFieldNames ? '' : 'sdpOffer',
        subBuilder: MediaEvent_SdpOffer.$_createMessage)
    ..aOM<MediaEvent_TrackBitrates>(8, _omitFieldNames ? '' : 'trackBitrates',
        subBuilder: MediaEvent_TrackBitrates.$_createMessage)
    ..aOM<MediaEvent_EnableTrackVariant>(
        9, _omitFieldNames ? '' : 'enableTrackVariant',
        subBuilder: MediaEvent_EnableTrackVariant.$_createMessage)
    ..aOM<MediaEvent_DisableTrackVariant>(
        10, _omitFieldNames ? '' : 'disableTrackVariant',
        subBuilder: MediaEvent_DisableTrackVariant.$_createMessage)
    ..aOM<MediaEvent_SetTargetTrackVariant>(
        11, _omitFieldNames ? '' : 'setTargetTrackVariant',
        subBuilder: MediaEvent_SetTargetTrackVariant.$_createMessage)
    ..aOM<MediaEvent_UnmuteTrack>(12, _omitFieldNames ? '' : 'unmuteTrack',
        subBuilder: MediaEvent_UnmuteTrack.$_createMessage)
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
  void clearContent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  MediaEvent_Connect get connect => $_getN(0);
  @$pb.TagNumber(1)
  set connect(MediaEvent_Connect value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasConnect() => $_has(0);
  @$pb.TagNumber(1)
  void clearConnect() => $_clearField(1);
  @$pb.TagNumber(1)
  MediaEvent_Connect ensureConnect() => $_ensure(0);

  @$pb.TagNumber(2)
  MediaEvent_Disconnect get disconnect => $_getN(1);
  @$pb.TagNumber(2)
  set disconnect(MediaEvent_Disconnect value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDisconnect() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisconnect() => $_clearField(2);
  @$pb.TagNumber(2)
  MediaEvent_Disconnect ensureDisconnect() => $_ensure(1);

  @$pb.TagNumber(3)
  MediaEvent_UpdateEndpointMetadata get updateEndpointMetadata => $_getN(2);
  @$pb.TagNumber(3)
  set updateEndpointMetadata(MediaEvent_UpdateEndpointMetadata value) =>
      $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUpdateEndpointMetadata() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpdateEndpointMetadata() => $_clearField(3);
  @$pb.TagNumber(3)
  MediaEvent_UpdateEndpointMetadata ensureUpdateEndpointMetadata() =>
      $_ensure(2);

  @$pb.TagNumber(4)
  MediaEvent_UpdateTrackMetadata get updateTrackMetadata => $_getN(3);
  @$pb.TagNumber(4)
  set updateTrackMetadata(MediaEvent_UpdateTrackMetadata value) =>
      $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdateTrackMetadata() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdateTrackMetadata() => $_clearField(4);
  @$pb.TagNumber(4)
  MediaEvent_UpdateTrackMetadata ensureUpdateTrackMetadata() => $_ensure(3);

  @$pb.TagNumber(5)
  MediaEvent_RenegotiateTracks get renegotiateTracks => $_getN(4);
  @$pb.TagNumber(5)
  set renegotiateTracks(MediaEvent_RenegotiateTracks value) =>
      $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRenegotiateTracks() => $_has(4);
  @$pb.TagNumber(5)
  void clearRenegotiateTracks() => $_clearField(5);
  @$pb.TagNumber(5)
  MediaEvent_RenegotiateTracks ensureRenegotiateTracks() => $_ensure(4);

  @$pb.TagNumber(6)
  $0.Candidate get candidate => $_getN(5);
  @$pb.TagNumber(6)
  set candidate($0.Candidate value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCandidate() => $_has(5);
  @$pb.TagNumber(6)
  void clearCandidate() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.Candidate ensureCandidate() => $_ensure(5);

  @$pb.TagNumber(7)
  MediaEvent_SdpOffer get sdpOffer => $_getN(6);
  @$pb.TagNumber(7)
  set sdpOffer(MediaEvent_SdpOffer value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSdpOffer() => $_has(6);
  @$pb.TagNumber(7)
  void clearSdpOffer() => $_clearField(7);
  @$pb.TagNumber(7)
  MediaEvent_SdpOffer ensureSdpOffer() => $_ensure(6);

  @$pb.TagNumber(8)
  MediaEvent_TrackBitrates get trackBitrates => $_getN(7);
  @$pb.TagNumber(8)
  set trackBitrates(MediaEvent_TrackBitrates value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasTrackBitrates() => $_has(7);
  @$pb.TagNumber(8)
  void clearTrackBitrates() => $_clearField(8);
  @$pb.TagNumber(8)
  MediaEvent_TrackBitrates ensureTrackBitrates() => $_ensure(7);

  @$pb.TagNumber(9)
  MediaEvent_EnableTrackVariant get enableTrackVariant => $_getN(8);
  @$pb.TagNumber(9)
  set enableTrackVariant(MediaEvent_EnableTrackVariant value) =>
      $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasEnableTrackVariant() => $_has(8);
  @$pb.TagNumber(9)
  void clearEnableTrackVariant() => $_clearField(9);
  @$pb.TagNumber(9)
  MediaEvent_EnableTrackVariant ensureEnableTrackVariant() => $_ensure(8);

  @$pb.TagNumber(10)
  MediaEvent_DisableTrackVariant get disableTrackVariant => $_getN(9);
  @$pb.TagNumber(10)
  set disableTrackVariant(MediaEvent_DisableTrackVariant value) =>
      $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasDisableTrackVariant() => $_has(9);
  @$pb.TagNumber(10)
  void clearDisableTrackVariant() => $_clearField(10);
  @$pb.TagNumber(10)
  MediaEvent_DisableTrackVariant ensureDisableTrackVariant() => $_ensure(9);

  @$pb.TagNumber(11)
  MediaEvent_SetTargetTrackVariant get setTargetTrackVariant => $_getN(10);
  @$pb.TagNumber(11)
  set setTargetTrackVariant(MediaEvent_SetTargetTrackVariant value) =>
      $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSetTargetTrackVariant() => $_has(10);
  @$pb.TagNumber(11)
  void clearSetTargetTrackVariant() => $_clearField(11);
  @$pb.TagNumber(11)
  MediaEvent_SetTargetTrackVariant ensureSetTargetTrackVariant() =>
      $_ensure(10);

  @$pb.TagNumber(12)
  MediaEvent_UnmuteTrack get unmuteTrack => $_getN(11);
  @$pb.TagNumber(12)
  set unmuteTrack(MediaEvent_UnmuteTrack value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasUnmuteTrack() => $_has(11);
  @$pb.TagNumber(12)
  void clearUnmuteTrack() => $_clearField(12);
  @$pb.TagNumber(12)
  MediaEvent_UnmuteTrack ensureUnmuteTrack() => $_ensure(11);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
