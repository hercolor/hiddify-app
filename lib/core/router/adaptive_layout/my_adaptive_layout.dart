import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/router/adaptive_layout/shell_route_action.dart';
import 'package:hiddify/core/widget/desktop/desktop_shell.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MyAdaptiveLayout extends HookConsumerWidget {
  const MyAdaptiveLayout({
    super.key,
    required this.navigationShell,
    required this.isMobileBreakpoint,
    required this.showProfilesAction,
  });

  final StatefulNavigationShell navigationShell;
  final bool isMobileBreakpoint;
  final bool showProfilesAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _actions(showProfilesAction, isMobileBreakpoint);
    if (PlatformUtils.isWindows) {
      return DesktopShell(navigationShell: navigationShell, actions: actions);
    }
    return Material(child: Scaffold(body: navigationShell));
  }

  List<ShellRouteAction> _actions(bool showProfilesAction, bool isMobileBreakpoint) => [
    ShellRouteAction(Icons.shield_rounded, '连接'),
    if (showProfilesAction && !isMobileBreakpoint) ShellRouteAction(Icons.view_list_rounded, '配置'),
    ShellRouteAction(Icons.language_rounded, '节点'),
    ShellRouteAction(Icons.person_rounded, '我的'),
  ];
}
