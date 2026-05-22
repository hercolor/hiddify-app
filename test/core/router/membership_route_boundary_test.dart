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

    expect(adaptiveLayoutText, contains("'连接'"));
    expect(adaptiveLayoutText, contains("'节点'"));
    expect(adaptiveLayoutText, contains("'我的'"));
    expect(
      adaptiveLayoutText,
      isNot(contains("'设置'")),
      reason: 'visible navigation label must be demo-style account page',
    );
    expect(
      adaptiveLayoutText,
      isNot(contains("'Settings'")),
      reason: 'visible navigation label must be demo-style account page',
    );

    for (final forbidden in ['DNS', 'TUN', 'fake-ip', 'IPv6', '高级设置', 'Kill Switch']) {
      expect(settingsText, isNot(contains(forbidden)), reason: 'legacy settings wrapper must not expose $forbidden');
    }
  });

  test('normal UI hides manual subscription controls and traffic details', () {
    final mobileMembershipText = _readUtf8('lib/features/auth/widget/user_profile_page.dart');
    final desktopMembershipText = _readUtf8('lib/features/auth/widget/desktop_membership_page.dart');
    final premiumText = _readUtf8('lib/features/premium/premium_screens.dart');
    final profilesPageText = _readUtf8('lib/features/profile/overview/profiles_page.dart');
    final profilesModalText = _readUtf8('lib/features/profile/overview/profiles_modal.dart');
    final shortcutText = _readUtf8('lib/features/shortcut/shortcut_wrapper.dart');
    final emptyProfilesHomeText = _readUtf8('lib/features/home/widget/empty_profiles_home_body.dart');
    final profileTileText = _readUtf8('lib/features/profile/widget/profile_tile.dart');

    expect(mobileMembershipText, contains(r"return '最多 $max 台';"));
    expect(desktopMembershipText, contains(r"return '最多 $max 台';"));
    expect(mobileMembershipText, isNot(contains(" / \${max")));
    expect(desktopMembershipText, isNot(contains(" / \${max")));
    expect(premiumText, contains('选择您的套餐方案'));
    expect(premiumText, isNot(contains('选择您的订阅方案')));

    for (final source in [profilesPageText, profilesModalText]) {
      expect(source, isNot(contains('foregroundProfilesUpdateNotifierProvider')));
      expect(source, isNot(contains('updateSubscriptions')));
    }
    expect(profilesPageText, isNot(contains('showAddProfile')));
    expect(shortcutText, isNot(contains('showAddProfile')));
    expect(shortcutText, isNot(contains('PasteIntent')));
    expect(emptyProfilesHomeText, isNot(contains('showAddProfile')));
    expect(profileTileText, isNot(contains('RemainingTrafficIndicator(subInfo.ratio)')));
    expect(profileTileText, isNot(contains('ProfileSubscriptionInfo(subInfo)')));
    expect(profileTileText, isNot(contains('LinkParser.generateSubShareLink')));
    expect(profileTileText, isNot(contains('share.urlToClipboard')));
  });

  test('mobile branch back handling returns to home without showing close controls', () {
    final adaptiveLayoutText = _readUtf8('lib/core/router/adaptive_layout/my_adaptive_layout.dart');
    final routerText = _readUtf8('lib/core/router/go_router/routing_config_notifier.dart');
    final homeText = _readUtf8('lib/features/home/widget/desktop_home_page.dart');

    expect(adaptiveLayoutText, contains('PopScope('));
    expect(adaptiveLayoutText, contains('canPop: navigationShell.currentIndex == 0'));
    expect(adaptiveLayoutText, contains('navigationShell.goBranch(0)'));
    expect(routerText, isNot(contains('canPop: false')));
    expect(homeText, contains('if (PlatformUtils.isWindows)'));
    expect(homeText, contains('Icons.close_rounded'));
    expect(homeText, contains('const SizedBox(width: 38, height: 38)'));
  });
}
