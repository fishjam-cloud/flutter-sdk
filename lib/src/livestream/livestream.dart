/// Shared WHIP/WHEP plumbing (SPEC §19).
///
/// Owner: **Data & Stats** agent.
library;

import 'package:fishjam_client/src/models/errors.dart';

/// Maps a failed POST status to a [LivestreamError] (SPEC §19).
///
/// Owner: Data & Stats.
LivestreamError livestreamErrorForStatus(
  int statusCode, {
  required bool publishing,
}) => throw UnimplementedError('Data & Stats');
