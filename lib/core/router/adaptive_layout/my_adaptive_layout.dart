import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/adaptive_layout/shell_route_action.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/core/router/go_router/routing_config_notifier.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_shell.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MyAdaptiveLayout extends HookConsumerWidget {
  const MyAdaptiveLayout({
    super.key,
    required this.navigationShell,
    required this.isMobileBreakpoint,
    required this.showProfilesAction,
  });
  // managed by go router(Shell Route)
  final StatefulNavigationShell navigationShell;
  final bool isMobileBreakpoint;
  final bool showProfilesAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final actions = _actions(t, showProfilesAction, isMobileBreakpoint);
    final selectedIndex = navigationShell.currentIndex < actions.length
        ? navigationShell.currentIndex
        : actions.length - 1;
    // focus switch management
    final primaryFocusHash = useState<int?>(null);
    final navScopeNode = useFocusScopeNode();
    useEffect(() {
      bool handler(KeyEvent event) {
        final arrows = isMobileBreakpoint ? KeyboardConst.verticalArrows : KeyboardConst.horizontalArrows;
        if (!arrows.contains(event.logicalKey)) return false;
        if (event is KeyDownEvent) {
          primaryFocusHash.value = FocusManager.instance.primaryFocus.hashCode;
        } else {
          // focus node does not change => true.
          if (primaryFocusHash.value == FocusManager.instance.primaryFocus.hashCode) {
            if (branchesScope.values.any((node) => node.hasFocus)) {
              navScopeNode.requestFocus();
            } else if (navScopeNode.hasFocus) {
              branchesScope[getNameOfBranch(isMobileBreakpoint, showProfilesAction, navigationShell.currentIndex)]
                  ?.requestFocus();
            }
          }
        }
        return true;
      }

      HardwareKeyboard.instance.addHandler(handler);
      return () {
        HardwareKeyboard.instance.removeHandler(handler);
      };
    }, [isMobileBreakpoint, showProfilesAction, navigationShell.currentIndex]);
    if (PlatformUtils.isWindows) {
      return DesktopShell(navigationShell: navigationShell, actions: actions);
    }
    return Material(
      child: Scaffold(
        body: isMobileBreakpoint
            ? navigationShell
            : Row(
                children: [
                  FocusScope(
                    node: navScopeNode,
                    child: NavigationRail(
                      extended: Breakpoint(context).isDesktop(),
                      destinations: _navRailDests(actions),
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) => _onTap(context, index),
                      trailing: Breakpoint(context).isDesktop()
                          ? const Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(width: 220, child: SideBarStatsOverview()),
                              ),
                            )
                          : null,
                    ),
                  ),
                  Expanded(child: navigationShell),
                ],
              ),
        bottomNavigationBar: isMobileBreakpoint
            ? FocusScope(
                node: navScopeNode,
                child: BottomNavigationBar(
                  currentIndex: selectedIndex,
                  onTap: (index) => _onTap(context, index),
                  backgroundColor: BrandColors.card,
                  elevation: 10,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: BrandColors.signalBlue,
                  unselectedItemColor: BrandColors.subtle,
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  items: _bottomNavItems(actions),
                ),
              )
            : null,
      ),
    );
  }

  // shell route action onTap
  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  List<ShellRouteAction> _actions(Translations t, bool showProfilesAction, bool isMobileBreakpoint) => [
    ShellRouteAction(Icons.shield_rounded, '连接'),
    if (showProfilesAction && !isMobileBreakpoint) ShellRouteAction(Icons.view_list_rounded, t.pages.profiles.title),
    ShellRouteAction(Icons.language_rounded, '节点'),
    ShellRouteAction(Icons.person_rounded, '我的'),
  ];

  List<NavigationRailDestination> _navRailDests(List<ShellRouteAction> actions) =>
      actions.map((e) => NavigationRailDestination(icon: Icon(e.icon), label: Text(e.title))).toList();
  List<BottomNavigationBarItem> _bottomNavItems(List<ShellRouteAction> actions) =>
      actions.map((e) => BottomNavigationBarItem(icon: Icon(e.icon), label: e.title)).toList();
}
