/// Reliable and lossy data channels with `ChannelMessage` framing
/// (SPEC §16).
///
/// Owner: **Data & Stats** agent.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/proto/fishjam/media_events/shared.pb.dart';
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
Uint8List encodeChannelMessage(Uint8List data, {required String source}) =>
    ChannelMessage(
      source: source,
      destinations: const ['*'],
      binary: ChannelMessageBinaryPayload(data: data),
    ).writeToBuffer();

/// Decodes a received `ChannelMessage`; `null` when it is undecodable or has
/// no binary payload.
Uint8List? decodeChannelMessage(Uint8List message) {
  final ChannelMessage decoded;
  try {
    decoded = ChannelMessage.fromBuffer(message);
  } on Object {
    return null;
  }
  if (!decoded.hasBinary()) return null;
  return Uint8List.fromList(decoded.binary.data);
}

/// Owns the two channels of a session.
///
/// The manager outlives sessions: [close] tears down the channels of the
/// current session, but [dataStream] subscriptions stay valid and receive
/// data from channels created later.
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

  final _reliableData = StreamController<Uint8List>.broadcast();
  final _lossyData = StreamController<Uint8List>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  RtcDataChannel? _reliable;
  RtcDataChannel? _lossy;

  /// The in-flight [createChannels] call, if any.
  Future<void>? _pending;

  /// Completes when both channels of the in-flight attempt are open.
  Completer<void>? _ready;

  /// Whether both channels are open.
  bool get isReady =>
      _reliable?.state == DataChannelState.open &&
      _lossy?.state == DataChannelState.open;

  /// Creates both channels; completes when both are open (SPEC §16).
  ///
  /// A no-op when both are open; concurrent calls share one attempt.
  Future<void> createChannels() {
    if (isReady) return Future.value();
    final pending = _pending;
    if (pending != null) return pending;
    // `_create` may finish synchronously (e.g. `negotiate` throws at once),
    // so the attempt is cleared on completion rather than inside it.
    final attempt = _pending = _create();
    attempt.whenComplete(() {
      if (identical(_pending, attempt)) _pending = null;
    }).ignore();
    return attempt;
  }

  Future<void> _create() async {
    unawaited(_discardChannels());
    final ready = Completer<void>();
    _ready = ready;
    try {
      await Future.wait([
        _negotiate((pc) => _apply(pc, ready)),
        ready.future,
      ], eagerError: true);
      if (!isReady) throw StateError('Data channel closed while opening');
    } on Object catch (error, stackTrace) {
      if (identical(_ready, ready)) {
        _finishAttempt();
        unawaited(_discardChannels());
        if (_isTeardown(error)) {
          // The engine failed the command because the session ended
          // (SPEC §8.3); like [close], this is a silent cancel.
          _logger.debug('Data channel creation cancelled by teardown');
        } else {
          _logger.error('Creating data channels failed', error, stackTrace);
          _emit(DataChannelsError(error));
        }
      }
      rethrow;
    }
    if (!identical(_ready, ready)) throw StateError('disconnected');
    _finishAttempt();
    _logger.debug('Data channels ready');
    _emit(const DataChannelsReady());
  }

  static bool _isTeardown(Object error) =>
      error is StateError && error.message == 'disconnected';

  void _finishAttempt() {
    _ready = null;
    _pending = null;
  }

  Future<void> _apply(RtcPeerConnection pc, Completer<void> ready) async {
    for (final reliable in const [true, false]) {
      if (!identical(_ready, ready)) throw StateError('disconnected');
      final channel = await pc.createDataChannel(
        reliable ? reliableLabel : lossyLabel,
        reliable ? reliableInit : lossyInit,
      );
      if (!identical(_ready, ready)) {
        unawaited(_closeQuietly(channel));
        throw StateError('disconnected');
      }
      if (reliable) {
        _reliable = channel;
      } else {
        _lossy = channel;
      }
      _subscriptions
        ..add(channel.onStateChange.listen((_) => _onStateChange(channel)))
        ..add(channel.onMessage.listen((m) => _onMessage(m, reliable)));
    }
    _onStateChange(_lossy!);
  }

  void _onStateChange(RtcDataChannel channel) {
    _logger.debug('Data channel ${channel.label} is ${channel.state.name}');
    final ready = _ready;
    if (ready == null || ready.isCompleted) return;
    final closed = [_reliable, _lossy].nonNulls.where(
      (c) =>
          c.state == DataChannelState.closing ||
          c.state == DataChannelState.closed,
    );
    if (closed.isNotEmpty) {
      ready.completeError(
        StateError('Data channel ${closed.first.label} closed before opening'),
      );
    } else if (isReady) {
      ready.complete();
    }
  }

  void _onMessage(Uint8List message, bool reliable) {
    final payload = decodeChannelMessage(message);
    final label = reliable ? reliableLabel : lossyLabel;
    if (payload == null) {
      _logger.warn(
        'Dropped data channel message on $label: undecodable or without a '
        'binary payload',
      );
      return;
    }
    (reliable ? _reliableData : _lossyData).add(payload);
  }

  /// Sends [data] on the chosen channel. Throws [StateError] when it is not
  /// open.
  void publish(Uint8List data, {required bool reliable}) {
    final channel = reliable ? _reliable : _lossy;
    final label = reliable ? reliableLabel : lossyLabel;
    if (channel == null) {
      throw StateError(
        'Data channel $label does not exist; call createDataChannels() first',
      );
    }
    if (channel.state != DataChannelState.open) {
      throw StateError(
        'Data channel $label is not open (${channel.state.name})',
      );
    }
    final message = encodeChannelMessage(data, source: _localPeerId());
    unawaited(
      channel.send(message).catchError((Object error, StackTrace stackTrace) {
        _logger.error(
          'Sending on data channel $label failed',
          error,
          stackTrace,
        );
      }),
    );
  }

  /// Payloads received on the chosen channel. May be listened to before the
  /// channels exist; cancel the subscription to unsubscribe.
  Stream<Uint8List> dataStream({required bool reliable}) =>
      (reliable ? _reliableData : _lossyData).stream;

  /// Closes both channels and fails a pending [createChannels] with
  /// `StateError('disconnected')` (SPEC §8.3). Emits nothing.
  Future<void> close() async {
    final ready = _ready;
    _finishAttempt();
    if (ready != null && !ready.isCompleted) {
      ready.completeError(StateError('disconnected'));
    }
    await _discardChannels();
  }

  /// Closes the channels like [close] and ends every [dataStream] (so
  /// `await for` loops finish). The facade calls it when the client is
  /// disposed; the manager is unusable afterwards.
  Future<void> dispose() async {
    await close();
    await Future.wait([_reliableData.close(), _lossyData.close()]);
  }

  Future<void> _discardChannels() async {
    final subscriptions = [..._subscriptions];
    final channels = [_reliable, _lossy].nonNulls.toList();
    _subscriptions.clear();
    _reliable = null;
    _lossy = null;
    await Future.wait([
      for (final s in subscriptions) s.cancel(),
      for (final c in channels) _closeQuietly(c),
    ]);
  }

  Future<void> _closeQuietly(RtcDataChannel channel) async {
    try {
      await channel.close();
    } on Object catch (error, stackTrace) {
      _logger.warn(
        'Closing data channel ${channel.label} failed',
        error,
        stackTrace,
      );
    }
  }
}
