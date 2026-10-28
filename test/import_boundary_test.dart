import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Only these files may import `flutter_webrtc` (AGENTS.md, import rule).
const _allowed = {
  'lib/fishjam_client.dart',
  'lib/src/fishjam_client.dart',
  'lib/src/livestream_api.dart',
  'lib/src/pip/picture_in_picture.dart',
  'lib/src/rtc/flutter_webrtc_adapter.dart',
};

/// Internal modules: pure Dart, tested with fakes. They must not import
/// `flutter_webrtc` nor the adapter that wraps it.
const _internal = [
  'lib/src/signaling/',
  'lib/src/engine/',
  'lib/src/tracks/',
  'lib/src/data/',
  'lib/src/stats/',
  'lib/src/livestream/',
];

Iterable<File> _libFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/proto/'));

void main() {
  test('flutter_webrtc is imported only at the public boundary', () {
    final importers = {
      for (final f in _libFiles())
        if (f.readAsStringSync().contains('package:flutter_webrtc/')) f.path,
    };
    final models = importers.where((p) => p.startsWith('lib/src/models/'));

    expect(importers.difference(_allowed).difference(models.toSet()), isEmpty);
  });

  test('internal modules do not import the flutter_webrtc adapter', () {
    for (final f in _libFiles()) {
      if (!_internal.any(f.path.startsWith)) continue;
      expect(
        f.readAsStringSync(),
        isNot(contains('flutter_webrtc')),
        reason: f.path,
      );
    }
  });
}
