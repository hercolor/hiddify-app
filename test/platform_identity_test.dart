import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('Android exposes only the BflyVPN callback scheme', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final gradle = _read('android/app/build.gradle');

    expect(gradle, contains('applicationId "pro.y88.bflyvpn"'));
    expect(manifest, contains('<data android:scheme="bflyvpn" android:host="pay" />'));
    expect(manifest, contains('<data android:scheme="bflyvpn" android:host="app" />'));
    for (final legacyScheme in ['hiddify', 'v2ray', 'v2rayn', 'v2rayng', 'clash', 'clashmeta', 'sing-box']) {
      expect(manifest, isNot(contains('<data android:scheme="$legacyScheme"')));
    }
  });

  test('Windows emits BflyVPN.exe and registers only bflyvpn', () {
    final cmake = _read('windows/CMakeLists.txt');
    final runnerCmake = _read('windows/runner/CMakeLists.txt');
    final msix = _read('windows/packaging/msix/make_config.yaml');

    expect(cmake, contains('project(BflyVPN LANGUAGES CXX)'));
    expect(cmake, contains('set(BINARY_NAME "BflyVPN")'));
    expect(runnerCmake, isNot(contains('OUTPUT_NAME')));
    expect(msix, contains('protocol_activation: bflyvpn'));
    expect(msix, contains('identity_name: HuDieJiaSu.Desktop'));
  });

  test('iOS signing and test targets use the locked bundle prefix', () {
    final workflow = _read('.github/workflows/build.yml');
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    final packetTunnelScheme = _read('ios/Runner.xcodeproj/xcshareddata/xcschemes/HiddifyPacketTunnel.xcscheme');

    expect(workflow, contains('bundle-id: pro.y88.bflyvpn'));
    expect(workflow, contains('bundle-id: pro.y88.bflyvpn.PacketTunnel'));
    expect(workflow, isNot(contains('bundle-id: pro.y88.hudiejiasu')));
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = pro.y88.bflyvpn.RunnerTests;'));
    expect(project, isNot(contains('PRODUCT_BUNDLE_IDENTIFIER = pro.y88.hudiejiasu.RunnerTests;')));
    expect(packetTunnelScheme, contains('BundleIdentifier = "pro.y88.bflyvpn"'));
  });

  test('release notes describe the new Android install identity', () {
    final releaseMessage = _read('.github/release_message.md');

    expect(releaseMessage, contains('Android 包名为 `pro.y88.bflyvpn`'));
    expect(releaseMessage, isNot(contains('Android 包名保持 `pro.y88.accelerator`')));
  });
}
