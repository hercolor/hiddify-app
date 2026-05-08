import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DesktopHomePage extends HookConsumerWidget {
  const DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientConnectionStateProvider);
    final nodeSelection = ref.watch(clientNodeSelectionProvider);
    final selectedNode = nodeSelection.valueOrNull?.selectedNode;
    final nodeName = nodeSelection.when(
      data: (selection) => safeNodeDisplayName(
        selection.selectedNode?.name ?? (selection.nodes.isNotEmpty ? selection.nodes.first.name : null),
        fallback: '暂无可用节点',
      ),
      error: (_, _) => '暂无可用节点',
      loading: () => '读取线路中',
    );
    final status = _statusInfo(state);

    return DesktopPageScaffold(
      title: '4376',
      actions: [Icon(Icons.security_rounded, color: status.color)],
      child: Column(
        children: [
          Expanded(child: _ConnectionCard(state: state)),
          const Gap(14),
          _HomeInfoCard(node: selectedNode, nodeName: nodeName),
          const Gap(12),
          _TodayTrafficCard(connected: state.phase == ClientConnectionPhase.connected),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.state});

  final ClientConnectionState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final busy = state.isBusy;
    final title = connected
        ? '已受保护'
        : busy
        ? '连接中...'
        : state.phase == ClientConnectionPhase.loggedOut
        ? '未登录'
        : '尚未连接';
    final subtitle = connected
        ? '连接稳定，正在保护您的网络'
        : busy
        ? '正在建立安全连接'
        : '点击按钮以保护您的隐私';

    return DesktopCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FA)]),
      borderColor: connected ? BrandDesktopColors.success.withValues(alpha: .28) : BrandDesktopColors.border,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: BrandDesktopColors.textPrimary, fontWeight: FontWeight.w900),
          ),
          const Gap(6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BrandDesktopColors.textSecondary),
          ),
          const Gap(54),
          Center(child: _DesktopPowerButton(state: state)),
        ],
      ),
    );
  }
}

class _DesktopPowerButton extends ConsumerWidget {
  const _DesktopPowerButton({required this.state});

  final ClientConnectionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final busy = state.isBusy;
    final failed = state.phase == ClientConnectionPhase.failed;
    final color = connected
        ? BrandDesktopColors.accent
        : failed
        ? BrandDesktopColors.error
        : busy
        ? BrandDesktopColors.warning
        : BrandDesktopColors.accent;
    return Semantics(
      button: true,
      enabled: state.canTap,
      label: state.buttonLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: state.canTap
                ? () async {
                    if (state.phase == ClientConnectionPhase.loggedOut) {
                      ref.read(connectionNotifierProvider.notifier).connectRequested();
                      if (context.mounted) context.goNamed('settings');
                      return;
                    }
                    await ref.read(connectionNotifierProvider.notifier).connectRequested();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? BrandDesktopColors.accent : BrandDesktopColors.cardSolid,
                border: Border.all(color: connected ? Colors.transparent : BrandDesktopColors.border),
                boxShadow: [
                  BoxShadow(
                    color: connected
                        ? BrandDesktopColors.accent.withValues(alpha: .30)
                        : Colors.black.withValues(alpha: .05),
                    blurRadius: connected ? 40 : 20,
                    spreadRadius: connected ? 10 : 5,
                    offset: const Offset(0, 10),
                  ),
                  if (busy) BoxShadow(color: color.withValues(alpha: .18), blurRadius: 40, spreadRadius: 8),
                ],
              ),
              child: Center(
                child: busy
                    ? SizedBox.square(dimension: 34, child: CircularProgressIndicator(strokeWidth: 3, color: color))
                    : Icon(
                        connected ? Icons.check_rounded : Icons.power_settings_new_rounded,
                        color: connected ? Colors.white : BrandDesktopColors.textMuted,
                        size: 80,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeInfoCard extends StatelessWidget {
  const _HomeInfoCard({required this.node, required this.nodeName});

  final ClientNode? node;
  final String nodeName;

  @override
  Widget build(BuildContext context) {
    final delay = node?.delay;
    final delayText = delay == null || delay == 0
        ? '待测速'
        : delay > 65000
        ? '不可用'
        : '$delay ms';
    return DesktopMetricTile(
      icon: Icons.hub_rounded,
      label: '当前节点',
      value: nodeName,
      accent: _delayColor(delay),
    ).withBadge(context, delayText, _delayColor(delay));
  }
}

class _TodayTrafficCard extends ConsumerWidget {
  const _TodayTrafficCard({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = connected ? ref.watch(statsNotifierProvider).valueOrNull : null;
    final usedBytes = connected ? ((stats?.uplinkTotal.toInt() ?? 0) + (stats?.downlinkTotal.toInt() ?? 0)) : 0;
    return DesktopMetricTile(
      icon: Icons.data_usage_rounded,
      label: '今日流量',
      value: usedBytes.sizeGB(),
      accent: BrandDesktopColors.accent,
    );
  }
}

extension _MetricBadgeX on DesktopMetricTile {
  Widget withBadge(BuildContext context, String label, Color color) {
    return Stack(
      children: [
        this,
        Positioned(
          right: 16,
          top: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

_StatusInfo _statusInfo(ClientConnectionState state) {
  return switch (state.phase) {
    ClientConnectionPhase.connected => const _StatusInfo('已连接', BrandDesktopColors.success, Icons.check_circle_rounded),
    ClientConnectionPhase.connecting ||
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission => const _StatusInfo(
      '连接中',
      BrandDesktopColors.warning,
      Icons.sync_rounded,
    ),
    ClientConnectionPhase.reconnecting => const _StatusInfo(
      '重连中',
      BrandDesktopColors.warning,
      Icons.restart_alt_rounded,
    ),
    ClientConnectionPhase.stopping => const _StatusInfo(
      '停止中',
      BrandDesktopColors.warning,
      Icons.power_settings_new_rounded,
    ),
    ClientConnectionPhase.failed => const _StatusInfo('连接异常', BrandDesktopColors.error, Icons.error_rounded),
    ClientConnectionPhase.loggedOut => const _StatusInfo('未登录', BrandDesktopColors.textMuted, Icons.person_off_rounded),
    ClientConnectionPhase.initializing => const _StatusInfo(
      '初始化中',
      BrandDesktopColors.textMuted,
      Icons.hourglass_top_rounded,
    ),
    _ => const _StatusInfo('未连接', BrandDesktopColors.textMuted, Icons.radio_button_unchecked_rounded),
  };
}

Color _delayColor(int? delay) {
  if (delay == null || delay == 0) return BrandDesktopColors.textMuted;
  if (delay < 800) return BrandDesktopColors.success;
  if (delay < 1500) return BrandDesktopColors.warning;
  return BrandDesktopColors.error;
}

class _StatusInfo {
  const _StatusInfo(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}
