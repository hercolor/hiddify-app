import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/widget/desktop/desktop_shell.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MyAdaptiveLayout extends HookConsumerWidget {
  const MyAdaptiveLayout({
    super.key,
    required this.navigationShell,
    required this.isMobileBreakpoint,
  });

  final StatefulNavigationShell navigationShell;
  final bool isMobileBreakpoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isWindows) {
      return DesktopShell(navigationShell: navigationShell);
    }
    final isLoggedIn = ref.watch(authNotifierProvider).valueOrNull?.isLoggedIn == true;
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || navigationShell.currentIndex == 0) return;
        navigationShell.goBranch(0);
      },
      child: Material(
        color: const Color(0xFFF5F6FA),
        child: Column(
          children: [
            Expanded(child: navigationShell),
            if (isLoggedIn) _MobileBottomNavBar(navigationShell: navigationShell),
          ],
        ),
      ),
    );
  }
}

class _MobileBottomNavBar extends HookConsumerWidget {
  const _MobileBottomNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavTab(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: '首页',
              isSelected: currentIndex == 0,
              onTap: () {
                HapticFeedback.lightImpact();
                navigationShell.goBranch(0);
              },
            ),
            _NavTab(
              icon: Icons.language_outlined,
              activeIcon: Icons.language_rounded,
              label: '节点',
              isSelected: currentIndex == 1,
              onTap: () {
                HapticFeedback.lightImpact();
                navigationShell.goBranch(1);
              },
            ),
            _NavTab(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: '会员',
              isSelected: currentIndex == 2,
              onTap: () {
                HapticFeedback.lightImpact();
                navigationShell.goBranch(2);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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
  }
}
