/// Socket URL, close-reason normalization and classification (SPEC §2.1,
/// §4).
///
/// Owner: **Signaling** agent.
library;

import 'package:fishjam_client/src/models/errors.dart';
import 'package:fishjam_client/src/signaling/transport.dart';

/// Path of the peer socket, appended to the Fishjam URL.
const peerSocketPath = 'socket/peer/websocket';

/// Builds the socket URL from the Fishjam [url] (SPEC §2.1): appends
/// [peerSocketPath] without duplicating a trailing `/`.
///
/// Owner: Signaling.
Uri peerSocketUrl(String url) => throw UnimplementedError('Signaling');

/// `reason.trim().toLowerCase()` (SPEC §4).
///
/// Owner: Signaling.
String normalizeCloseReason(String reason) =>
    throw UnimplementedError('Signaling');

/// Classifies a transport close (SPEC §4). A close without a close frame is
/// always [RetryableClose].
///
/// Owner: Signaling.
CloseReason classifyClose(TransportClosed closed) =>
    throw UnimplementedError('Signaling');
