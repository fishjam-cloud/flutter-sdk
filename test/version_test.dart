import 'dart:io';

import 'package:fishjam_client/src/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('packageVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);

    expect(packageVersion, version);
  });

  test('sdkVersion is flutter-<semver>', () {
    expect(sdkVersion, 'flutter-$packageVersion');
    expect(sdkVersion, matches(RegExp(r'^flutter-\d+\.\d+\.\d+$')));
  });
}
