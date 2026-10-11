/// Conversions between public models and protobuf messages.
library;

import 'dart:convert';

import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/server/server.pb.dart'
    as server;
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pbenum.dart'
    as shared;

/// Encodes [value] as metadata JSON. `null` becomes `"null"`, never `""`
/// (the server drops events with empty JSON).
String encodeMetadataJson(Object? value) => jsonEncode(value);

/// Decodes metadata JSON received from the server. An empty string decodes
/// to `null`; undecodable input is reported through [onError] and decodes to
/// `null` (never throws).
Object? decodeMetadataJson(
  String json, {
  void Function(FormatException error)? onError,
}) {
  if (json.isEmpty) return null;
  try {
    return jsonDecode(json);
  } on FormatException catch (e) {
    onError?.call(e);
    return null;
  }
}

shared.Variant variantToProto(Variant variant) => switch (variant) {
  Variant.low => shared.Variant.VARIANT_LOW,
  Variant.medium => shared.Variant.VARIANT_MEDIUM,
  Variant.high => shared.Variant.VARIANT_HIGH,
};

/// Maps a protobuf variant to the public [Variant]; `null` for
/// `VARIANT_UNSPECIFIED` and unknown values.
Variant? variantFromProto(shared.Variant variant) => switch (variant) {
  shared.Variant.VARIANT_LOW => Variant.low,
  shared.Variant.VARIANT_MEDIUM => Variant.medium,
  shared.Variant.VARIANT_HIGH => Variant.high,
  _ => null,
};

/// Converts a server simulcast config; a missing config means disabled.
SimulcastConfig simulcastConfigFromProto(
  server.MediaEvent_Track_SimulcastConfig? config,
) {
  if (config == null) return const SimulcastConfig.disabled();
  return SimulcastConfig(
    enabled: config.enabled,
    enabledVariants: config.enabledVariants
        .map(variantFromProto)
        .nonNulls
        .toList(growable: false),
    disabledVariants: config.disabledVariants
        .map(variantFromProto)
        .nonNulls
        .toList(growable: false),
  );
}
