import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/adaptive_layout/shell_route_action.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key, required this.navigationShell, required this.actions});

  final StatefulNavigationShell navigationShell;
  final List<ShellRouteAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientConnectionStateProvider);
    final nodeName = ref.watch(clientNodeSelectionProvider).valueOrNull?.selectedNode?.name ?? '暂无可用节点';
    return DesktopTheme(
      child: Material(
        color: BrandDesktopColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;
            final selectedIndex = navigationShell.currentIndex.clamp(0, actions.length - 1);
            return Row(
              children: [
                _Sidebar(
                  compact: compact,
                  selectedIndex: selectedIndex,
                  actions: actions,
                  state: state,
                  nodeName: nodeName,
                  onSelected: (index) => navigationShell.goBranch(index, initialLocation: index == selectedIndex),
                ),
                Expanded(child: navigationShell),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.selectedIndex,
    required this.actions,
    required this.state,
    required this.nodeName,
    required this.onSelected,
  });

  final bool compact;
  final int selectedIndex;
  final List<ShellRouteAction> actions;
  final ClientConnectionState state;
  final String nodeName;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 88.0 : 244.0;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: BrandDesktopColors.panel.withValues(alpha: .92),
        border: Border(right: BorderSide(color: BrandDesktopColors.border.withValues(alpha: .80))),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 20, compact ? 12 : 18, 18),
          child: Column(
            crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
            children: [
              if (compact)
                const BrandMark(size: 44, showWordmark: false, dark: true)
              else
                BrandMark(
                  size: 42,
                  dark: true,
                  wordmarkStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: BrandDesktopColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.7,
                  ),
                ),
              const Gap(28),
              for (var i = 0; i < actions.length; i++) ...[
                _NavItem(
                  compact: compact,
                  icon: actions[i].icon,
                  label: actions[i].title,
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
                const Gap(8),
              ],
              const Spacer(),
              if (!compact) _StatusPanel(state: state, nodeName: nodeName),
              if (!compact) const Gap(12),
              Text(
                Constants.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: BrandDesktopColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.compact,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final bool compact;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BrandDesktopColors.textPrimary : BrandDesktopColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
          decoration: BoxDecoration(
            gradient: selected ? BrandDesktopGradients.primary : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Colors.white.withValues(alpha: .12) : Colors.transparent),
            boxShadow: selected ? BrandDesktopShadows.glow(BrandDesktopColors.accent, alpha: .12) : null,
          ),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? Colors.white : color, size: 23),
              if (!compact) ...[
                const Gap(12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: selected ? Colors.white : color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.state, required this.nodeName});

  final ClientConnectionState state;
  final String nodeName;

  @override
  Widget build(BuildContext context) {
    final color = switch (state.phase) {
      ClientConnectionPhase.connected => BrandDesktopColors.success,
      ClientConnectionPhase.failed => BrandDesktopColors.error,
      ClientConnectionPhase.connecting ||
      ClientConnectionPhase.preparing ||
      ClientConnectionPhase.requestingVpnPermission ||
      ClientConnectionPhase.reconnecting => BrandDesktopColors.warning,
      _ => BrandDesktopColors.textMuted,
    };
    final label = switch (state.phase) {
      ClientConnectionPhase.connected => '已连接',
      ClientConnectionPhase.connecting ||
      ClientConnectionPhase.preparing ||
      ClientConnectionPhase.requestingVpnPermission => '连接中',
      ClientConnectionPhase.reconnecting => '重连中',
      ClientConnectionPhase.failed => '连接异常',
      ClientConnectionPhase.loggedOut => '未登录',
      ClientConnectionPhase.initializing => '初始化中',
      _ => '未连接',
    };
    return DesktopCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopStatusPill(label: label, color: color),
          const Gap(12),
          Text('当前节点', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textMuted)),
          const Gap(4),
          Text(
            _safeNodeName(nodeName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: BrandDesktopColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

String _safeNodeName(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'https?://[^\s]+'), '***')
      .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '***')
      .replaceAll(RegExp(r'\b[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:\d+)?\b'), '***');
  return sanitized.trim().isEmpty ? '暂无可用节点' : sanitized;
}
