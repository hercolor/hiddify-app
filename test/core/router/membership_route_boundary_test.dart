import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readUtf8(String path) => utf8.decode(File(path).readAsBytesSync());

void main() {
  test('legacy /settings route is a membership/login compatibility boundary', () {
    final routerText = _readUtf8('lib/core/router/go_router/routing_config_notifier.dart');
    final connectionText = _readUtf8('lib/features/home/widget/connection_button.dart');
    final desktopHomeText = _readUtf8('lib/features/home/widget/desktop_home_page.dart');
    final settingsText = _readUtf8('lib/features/settings/overview/settings_page.dart');
    final adaptiveLayoutText = _readUtf8('lib/core/router/adaptive_layout/my_adaptive_layout.dart');

    expect(routerText, contains("path: '/settings'"));
    expect(routerText, contains('child: const SettingsPage()'));
    expect(settingsText, contains('UserProfilePage'));

    expect(connectionText, contains("context.goNamed('settings')"));
    expect(desktopHomeText, contains("context.goNamed('settings')"));

    expect(adaptiveLayoutText, contains("'首页'"));
    expect(adaptiveLayoutText, contains("'节点'"));
    expect(adaptiveLayoutText, contains("'会员'"));
    expect(adaptiveLayoutText, isNot(contains("'设置'")), reason: 'visible navigation label must be Membership/会员');
    expect(adaptiveLayoutText, isNot(contains("'Settings'")), reason: 'visible navigation label must be Membership/会员');

    for (final forbidden in ['DNS', 'TUN', 'fake-ip', 'IPv6', '高级设置', 'Kill Switch']) {
      expect(settingsText, isNot(contains(forbidden)), reason: 'legacy settings wrapper must not expose $forbidden');
    }
  });
}
