/// Scriptable [NetworkMonitor] for unit tests.
library;

import 'dart:async';

import 'package:fishjam_client/src/signaling/network_monitor.dart';

/// A fake OS network report: the test sets the current networks and pushes
/// reports.
class FakeNetworkMonitor implements NetworkMonitor {
  /// Starts with [networks] in use.
  FakeNetworkMonitor({Set<String> networks = const {'wifi'}})
    : _current = networks;

  Set<String> _current;
  final _reports = StreamController<Set<String>>.broadcast();

  /// When set, [current] waits for it.
  Completer<void>? currentGate;

  /// When set, [current] throws it.
  Error? currentError;

  /// When set, reading [changes] throws it.
  Error? changesError;

  /// Whether anyone listens to [changes].
  bool get isWatched => _reports.hasListener;

  @override
  Future<Set<String>> current() async {
    final gate = currentGate;
    if (gate != null) await gate.future;
    final error = currentError;
    if (error != null) throw error;
    return _current;
  }

  @override
  Stream<Set<String>> get changes {
    final error = changesError;
    if (error != null) throw error;
    return _reports.stream;
  }

  /// The OS reports [networks] (also when they did not change).
  void report(Set<String> networks) {
    _current = networks;
    _reports.add(networks);
  }

  /// The OS report stream fails.
  void fail(Object error) => _reports.addError(error);
}
