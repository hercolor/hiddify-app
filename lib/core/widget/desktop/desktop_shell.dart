import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/router/adaptive_layout/shell_route_action.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key, required this.navigationShell, required this.actions});

  final StatefulNavigationShell navigationShell;
  final List<ShellRouteAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DesktopTheme(
      child: Material(
        color: BrandDesktopColors.background,
        child: Stack(
          children: [
            const Positioned(left: 0, top: 0, right: 58, height: 16, child: DragToMoveArea(child: SizedBox.expand())),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: BrandDesktopWindow.contentMaxWidth),
                child: Column(
                  children: [
                    Expanded(child: navigationShell),
                    _BottomNavigation(
                      selectedIndex: navigationShell.currentIndex.clamp(0, actions.length - 1),
                      actions: actions,
                      onSelected: (index) =>
                          navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(top: 10, right: 10, child: _DesktopCloseButton()),
          ],
        ),
      ),
    );
  }
}

class _DesktopCloseButton extends StatelessWidget {
  const _DesktopCloseButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '关闭',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: windowManager.close,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BrandDesktopColors.card.withOpacity(.92),
              border: Border.all(color: BrandDesktopColors.border.withOpacity(.86)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: const Icon(Icons.close_rounded, size: 19, color: BrandDesktopColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.selectedIndex, required this.actions, required this.onSelected});

  final int selectedIndex;
  final List<ShellRouteAction> actions;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: BrandDesktopWindow.bottomNavHeight,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: BrandDesktopColors.panel.withOpacity(.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: BrandDesktopColors.border.withOpacity(.86)),
          boxShadow: BrandDesktopShadows.card,
        ),
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++)
              Expanded(
                child: _NavItem(
                  icon: actions[i].icon,
                  label: actions[i].title,
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : BrandDesktopColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected ? BrandDesktopGradients.primary : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Colors.white.withOpacity(.12) : Colors.transparent),
            boxShadow: selected ? BrandDesktopShadows.glow(BrandDesktopColors.accent, alpha: .10) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
