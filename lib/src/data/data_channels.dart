/// Reliable and lossy data channels with `ChannelMessage` framing
/// (SPEC §16).
///
/// Owner: **Data & Stats** agent.
library;

// Constructor fields are kept for the Data & Stats implementation.
// ignore_for_file: unused_field

import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

/// Label of the ordered, reliable channel. The server accepts no other
/// labels than [reliableLabel] and [lossyLabel].
const reliableLabel = 'reliable';

/// Label of the unordered, no-retransmission channel.
const lossyLabel = 'lossy';

/// Options of the reliable channel.
const reliableInit = DataChannelInit();

/// Options of the lossy channel.
const lossyInit = DataChannelInit(ordered: false, maxRetransmits: 0);

/// Encodes [data] as `ChannelMessage{source, destinations: ["*"],
/// binary{data}}` (SPEC §16).
///
/// Owner: Data & Stats.
Uint8List encodeChannelMessage(Uint8List data, {required String source}) =>
    throw UnimplementedError('Data & Stats');

/// Decodes a received `ChannelMessage`; `null` when it is undecodable or has
/// no binary payload.
///
/// Owner: Data & Stats.
Uint8List? decodeChannelMessage(Uint8List message) =>
    throw UnimplementedError('Data & Stats');

/// Owns the two channels of a session.
///
/// Owner: Data & Stats.
class DataChannelManager {
  /// Creates a manager. `negotiate` runs a batchable negotiating command
  /// that creates the channels on the peer connection (`RtcEngine.negotiate`).
  DataChannelManager({
    required this._logger,
    required this._negotiate,
    required this._emit,
    required this._localPeerId,
  });

  final FishjamLogger _logger;
  final Future<void> Function(Future<void> Function(RtcPeerConnection pc) apply)
  _negotiate;
  final void Function(FishjamEvent event) _emit;
  final String Function() _localPeerId;

  /// Whether both channels are open.
  bool get isReady => throw UnimplementedError('Data & Stats');

  /// Creates both channels; completes when both are open (SPEC §16).
  Future<void> createChannels() => throw UnimplementedError('Data & Stats');

  /// Sends [data] on the chosen channel. Throws [StateError] when it is not
  /// open.
  void publish(Uint8List data, {required bool reliable}) =>
      throw UnimplementedError('Data & Stats');

  /// Payloads received on the chosen channel. May be listened to before the
  /// channels exist.
  Stream<Uint8List> dataStream({required bool reliable}) =>
      throw UnimplementedError('Data & Stats');

  /// Closes both channels.
  Future<void> close() => throw UnimplementedError('Data & Stats');
}
