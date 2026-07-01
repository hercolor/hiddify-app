import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/core/widget/desktop/desktop_window_chrome.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final isHomePage = currentLocation == '/' || currentLocation == '/home';

    return DesktopTheme(
      child: Material(
        color: const Color(0xFFF5F6FA),
        child: DesktopWindowChrome(
          showCloseButton: isHomePage,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: BrandDesktopWindow.contentMaxWidth),
                    child: navigationShell,
                  ),
                ),
              ),
              _BottomNavBar(navigationShell: navigationShell),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavTab {
  const _BottomNavTab({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _tabs = [
  _BottomNavTab(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '首页'),
  _BottomNavTab(icon: Icons.language_outlined, activeIcon: Icons.language_rounded, label: '节点'),
  _BottomNavTab(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: '会员'),
];

class _BottomNavBar extends HookConsumerWidget {
  const _BottomNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authNotifierProvider).valueOrNull?.isLoggedIn == true;

    // 未登录时只展示「会员」tab
    if (!isLoggedIn) {
      return Container(
        height: BrandDesktopWindow.bottomNavHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: SafeArea(
          top: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              navigationShell.goBranch(2);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_rounded, size: 22, color: Color(0xFF6366F1)),
                const SizedBox(height: 2),
                Text(
                  '会员',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: BrandDesktopWindow.bottomNavHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final isSelected = navigationShell.currentIndex == index;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.lightImpact();
                  navigationShell.goBranch(index);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? tab.activeIcon : tab.icon,
                      size: 22,
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
