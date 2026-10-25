import 'dart:async';

import 'package:fishjam_client/src/logger.dart';

/// The device's networks as the OS reports them. Signaling depends only on
/// this seam; tests use `test/fakes/fake_network.dart`.
abstract interface class NetworkMonitor {
  /// The kinds of network in use (e.g. `wifi`, `mobile`); empty when
  /// offline. Throws when the OS cannot be asked.
  Future<Set<String>> current();

  /// Every report the OS makes; a report may repeat the previous one.
  Stream<Set<String>> get changes;
}

enum NetworkChange {
  /// The device went offline.
  lost,

  /// The device is online again after being offline.
  available,

  /// A network went away while another remains.
  changed,
}

/// Turns [NetworkMonitor] reports into [NetworkChange]s (SPEC §6.1): the
/// first value is the baseline, and every report is compared with the one
/// before it as it arrives.
/// When the OS cannot be asked, it logs a warning and reports nothing.
class NetworkWatcher {
  NetworkWatcher({
    required this._monitor,
    required this._logger,
    required this._onChanged,
  });

  final NetworkMonitor _monitor;
  final FishjamLogger _logger;
  final void Function(NetworkChange change) _onChanged;

  StreamSubscription<Set<String>>? _subscription;

  /// Bumped by [stop] (and so by every [start]): a start still reading the
  /// start value gives up when it is no longer the latest.
  int _runs = 0;

  /// The networks of the last report; `null` before the baseline.
  Set<String>? _last;

  /// Starts watching with a new baseline (stops a previous watch first).
  Future<void> start() async {
    stop();
    final run = _runs;
    try {
      // Read first: a platform that cannot be asked reports a failed
      // subscription to the framework's error handler, not to the stream.
      final networks = await _monitor.current();
      if (run != _runs) return;
      _subscription = _monitor.changes.listen(
        _onReport,
        onError: (Object e) {
          _logger.warn('Network reports failed; stopped watching them', e);
          stop();
        },
      );
      _last = networks;
    } on Object catch (e) {
      // A newer start may be watching already; this one only had to give up.
      if (run == _runs) {
        _logger.warn('Cannot read the network state; not watching it', e);
      }
    }
  }

  void stop() {
    _runs++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _last = null;
  }

  void _onReport(Set<String> networks) {
    final change = _classify(_last!, networks);
    _last = networks;
    if (change != null) _onChanged(change);
  }

  static NetworkChange? _classify(Set<String> last, Set<String> now) {
    if (now.isEmpty) return last.isEmpty ? null : NetworkChange.lost;
    if (last.isEmpty) return NetworkChange.available;
    // Only losing a network can break the connection's path; gaining one
    // (mobile data next to Wi-Fi, a VPN coming up) leaves it in place.
    return now.containsAll(last) ? null : NetworkChange.changed;
  }
}
