/// Scriptable [NetworkSource] for unit tests.
library;

import 'dart:async';

import 'package:fishjam_client/src/signaling/network_source.dart';

/// A fake OS network report: the test sets the current networks and pushes
/// reports.
class FakeNetworkSource implements NetworkSource {
  /// Starts with [networks] in use.
  FakeNetworkSource({Set<String> networks = const {'wifi'}})
    : _current = networks;

  Set<String> _current;
  final _reports = StreamController<Set<String>>.broadcast();

  /// When set, [getNetworkTypes] waits for it.
  Completer<void>? getNetworkTypesGate;

  /// When set, [getNetworkTypes] throws it.
  Error? getNetworkTypesError;

  /// When set, reading [networkTypesChanged] throws it.
  Error? networkTypesChangedError;

  /// Whether anyone listens to [networkTypesChanged].
  bool get isWatched => _reports.hasListener;

  @override
  Future<Set<String>> getNetworkTypes() async {
    final gate = getNetworkTypesGate;
    if (gate != null) await gate.future;
    final error = getNetworkTypesError;
    if (error != null) throw error;
    return _current;
  }

  @override
  Stream<Set<String>> get networkTypesChanged {
    final error = networkTypesChangedError;
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
