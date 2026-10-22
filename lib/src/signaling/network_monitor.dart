import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fishjam_client/src/logger.dart';

/// The device's networks as the OS reports them. Signaling depends only on
/// this seam; tests use `test/fakes/fake_network.dart`.
abstract interface class NetworkMonitor {
  /// The kinds of network in use (e.g. `wifi`, `cellular`); empty when
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

  /// A network went away, or the same networks were reached through offline.
  changed,
}

/// Turns [NetworkMonitor] reports into [NetworkChange]s (SPEC §6.1): the
/// first value is the baseline, and reports are acted on once they have been
/// stable for [settle], except a network reported after offline, which is
/// acted on at once; each change carries the time its first report arrived.
/// When the OS cannot be asked, it logs a warning and reports nothing.
class NetworkWatcher {
  NetworkWatcher({
    required this._monitor,
    required this._logger,
    required this._onChanged,
    this.settle = const Duration(milliseconds: 500),
  });

  final NetworkMonitor _monitor;
  final FishjamLogger _logger;
  final void Function(NetworkChange change, DateTime began) _onChanged;
  final Duration settle;

  StreamSubscription<Set<String>>? _subscription;

  /// The last settled networks; `null` before the baseline.
  Set<String>? _last;

  Timer? _settling;

  /// When the first report of the change still settling arrived.
  DateTime? _began;

  /// Whether the change still settling went through offline.
  bool _wentOffline = false;

  /// Starts watching with a new baseline (stops a previous watch first).
  Future<void> start() async {
    await stop();
    try {
      _subscription = _monitor.changes.listen(
        _onReport,
        onError: (Object e) {
          _logger.warn('Network reports failed; stopped watching them', e);
          unawaited(stop());
        },
      );
      final networks = await _monitor.current();
      if (_subscription != null) _last ??= networks;
    } on Object catch (e) {
      _logger.warn('Cannot read the network state; not watching it', e);
      await stop();
    }
  }

  Future<void> stop() async {
    final cancelled = _subscription?.cancel();
    _subscription = null;
    _last = null;
    _settling?.cancel();
    _settling = null;
    _began = null;
    _wentOffline = false;
    await cancelled;
  }

  void _onReport(Set<String> networks) {
    if (_last == null) {
      _last = networks;
      return;
    }
    // Platforms report a short "offline" while they switch the default
    // network; acting on it would cost a reconnection of its own.
    _began ??= clock.now();
    if (networks.isEmpty) _wentOffline = true;
    _settling?.cancel();
    if (networks.isNotEmpty && (_wentOffline || _last!.isEmpty)) {
      // A network after offline can only mean a new session is needed;
      // settling would only delay it.
      _settled(networks);
      return;
    }
    _settling = Timer(settle, () => _settled(networks));
  }

  void _settled(Set<String> networks) {
    final began = _began!;
    final change = _classify(_last!, networks, throughOffline: _wentOffline);
    _last = networks;
    _settling = null;
    _began = null;
    _wentOffline = false;
    if (change != null) _onChanged(change, began);
  }

  static NetworkChange? _classify(
    Set<String> last,
    Set<String> now, {
    required bool throughOffline,
  }) {
    if (now.isEmpty) return last.isEmpty ? null : NetworkChange.lost;
    if (last.isEmpty) return NetworkChange.available;
    // Another Wi-Fi network reports the same set as the one that was lost.
    if (throughOffline) return NetworkChange.changed;
    // Only losing a network can break the connection's path; gaining one
    // (cellular next to Wi-Fi, a VPN coming up) leaves it in place.
    return now.containsAll(last) ? null : NetworkChange.changed;
  }
}
