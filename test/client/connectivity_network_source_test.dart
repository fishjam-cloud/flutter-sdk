import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:fishjam_client/src/connectivity_network_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends ConnectivityPlatform {
  List<ConnectivityResult> current = [ConnectivityResult.wifi];
  final reports = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => reports.stream;
}

void main() {
  late _FakePlatform platform;

  setUp(() => ConnectivityPlatform.instance = platform = _FakePlatform());

  test('reports the kinds of network in use', () async {
    platform.current = [ConnectivityResult.mobile, ConnectivityResult.vpn];

    expect(await ConnectivityNetworkSource().current(), {'mobile', 'vpn'});
  });

  test('none is reported as no network', () async {
    final reports = <Set<String>>[];
    final subscription = ConnectivityNetworkSource().changes.listen(
      reports.add,
    );
    addTearDown(subscription.cancel);

    platform.reports
      ..add([ConnectivityResult.none])
      ..add([
        ConnectivityResult.wifi,
        ConnectivityResult.ethernet,
        ConnectivityResult.bluetooth,
        ConnectivityResult.satellite,
        ConnectivityResult.other,
      ]);
    await Future<void>.delayed(Duration.zero);

    expect(reports, [
      <String>{},
      {'wifi', 'ethernet', 'bluetooth', 'satellite', 'other'},
    ]);
  });
}
