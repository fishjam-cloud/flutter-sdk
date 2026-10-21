import 'dart:async';

import 'package:collection/collection.dart';
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

/// Turns [NetworkMonitor] reports into changes (SPEC §6.1): the first value
/// is the baseline and a report equal to the previous one is ignored. When
/// the OS cannot be asked, it logs a warning and reports nothing.
class NetworkWatcher {
  NetworkWatcher({
    required this._monitor,
    required this._logger,
    required this._onChanged,
  });

  final NetworkMonitor _monitor;
  final FishjamLogger _logger;
  final void Function({required bool online}) _onChanged;

  StreamSubscription<Set<String>>? _subscription;
  Set<String>? _last;

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
    await cancelled;
  }

  void _onReport(Set<String> networks) {
    final last = _last;
    _last = networks;
    if (last == null || const SetEquality<String>().equals(last, networks)) {
      return;
    }
    _onChanged(online: networks.isNotEmpty);
  }
}
