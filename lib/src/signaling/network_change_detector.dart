import 'dart:async';

import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/signaling/network_source.dart';

enum NetworkChange {
  /// The device went offline.
  lost,

  /// The device is online again after being offline.
  available,

  /// A network went away while another remains.
  changed,
}

/// Compares each OS report with the previous one and calls [_onChanged] with
/// the kind of change. If the OS cannot be asked, logs a warning and reports
/// nothing (SPEC §6.1).
class NetworkChangeDetector {
  NetworkChangeDetector({
    required this._source,
    required this._logger,
    required this._onChanged,
  });

  final NetworkSource _source;
  final FishjamLogger _logger;
  final void Function(NetworkChange change) _onChanged;

  StreamSubscription<Set<String>>? _subscription;
  int _generation = 0;

  /// `null` until [start] reads the first value.
  Set<String>? _previousNetworks;

  /// Starts watching with a new baseline (stops a previous watch first).
  Future<void> start() async {
    stop();
    final generation = _generation;
    try {
      // Read first: a platform that cannot be asked reports a failed
      // subscription to the framework's error handler, not to the stream.
      final networks = await _source.current();
      if (generation != _generation) return;
      _subscription = _source.changes.listen(
        _onNetworksReported,
        onError: (Object e) {
          _logger.warn('Network reports failed; stopped watching them', e);
          stop();
        },
      );
      _previousNetworks = networks;
    } on Object catch (e) {
      if (generation == _generation) {
        _logger.warn('Cannot read the network state; not watching it', e);
      }
    }
  }

  void stop() {
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _previousNetworks = null;
  }

  void _onNetworksReported(Set<String> networks) {
    final change = _classifyNetworkChange(_previousNetworks!, networks);
    _previousNetworks = networks;
    if (change != null) _onChanged(change);
  }

  static NetworkChange? _classifyNetworkChange(
    Set<String> previous,
    Set<String> current,
  ) {
    if (current.isEmpty) return previous.isEmpty ? null : NetworkChange.lost;
    if (previous.isEmpty) return NetworkChange.available;
    // Only losing a network can break the connection's path; gaining one
    // (mobile data next to Wi-Fi, a VPN coming up) leaves it in place.
    return current.containsAll(previous) ? null : NetworkChange.changed;
  }
}
