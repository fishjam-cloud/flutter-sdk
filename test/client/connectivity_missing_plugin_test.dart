import 'package:fishjam_client/src/connectivity_network_source.dart';
import 'package:fishjam_client/src/logger.dart';
import 'package:fishjam_client/src/signaling/network_change_detector.dart';
import 'package:flutter_test/flutter_test.dart';

// No platform implementation is registered here, as in an app's widget test.
void main() {
  testWidgets('without the plugin, watching only logs a warning; nothing is '
      'reported to the framework', (tester) async {
    final logs = <String>[];
    final detector = NetworkChangeDetector(
      source: ConnectivityNetworkSource(),
      logger: FishjamLogger(
        enabled: true,
        sink: (level, message, {error, stackTrace}) =>
            logs.add('${level.name}: $message'),
      ),
      onChanged: (_) {},
    );

    // Platform channels answer in real time.
    await tester.runAsync(() async {
      await detector.start();
      detector.stop();
    });

    expect(logs, [startsWith('warn')]);
  });
}
