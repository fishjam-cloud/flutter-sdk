import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fishjam_client/src/signaling/network_monitor.dart';

/// [NetworkMonitor] backed by `connectivity_plus`.
final class ConnectivityNetworkMonitor implements NetworkMonitor {
  @override
  Future<Set<String>> current() async =>
      _kinds(await Connectivity().checkConnectivity());

  @override
  Stream<Set<String>> get changes =>
      Connectivity().onConnectivityChanged.map(_kinds);

  static Set<String> _kinds(List<ConnectivityResult> results) => {
    for (final result in results)
      if (result != ConnectivityResult.none) result.name,
  };
}
