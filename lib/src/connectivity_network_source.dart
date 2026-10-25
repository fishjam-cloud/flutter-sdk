import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fishjam_client/src/signaling/network_source.dart';

/// [NetworkSource] backed by `connectivity_plus`.
final class ConnectivityNetworkSource implements NetworkSource {
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
