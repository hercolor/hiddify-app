import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
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
      data: (selection) => _safeNodeName(selection.selectedNode?.name ?? '暂无可用节点'),
      error: (_, _) => '暂无可用节点',
      loading: () => '读取线路中',
    );
    final status = _statusInfo(state);

    return DesktopPageScaffold(
      title: '首页',
      subtitle: '一键开启稳定、安全的网络加速体验',
      actions: [DesktopStatusPill(label: status.label, color: status.color, icon: status.icon)],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          final hero = _ConnectionHero(state: state, status: status, nodeName: nodeName);
          final side = _HomeSideCards(
            node: selectedNode,
            nodeName: nodeName,
            connected: state.phase == ClientConnectionPhase.connected,
          );
          if (narrow) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SizedBox(height: 560, child: hero),
                const Gap(18),
                side,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: hero),
              const Gap(22),
              Expanded(flex: 4, child: side),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionHero extends ConsumerWidget {
  const _ConnectionHero({required this.state, required this.status, required this.nodeName});

  final ClientConnectionState state;
  final _StatusInfo status;
  final String nodeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final connected = state.phase == ClientConnectionPhase.connected;
    final busy = state.isBusy;
    return DesktopCard(
      padding: const EdgeInsets.all(30),
      gradient: const LinearGradient(
        colors: [Color(0xE5192740), Color(0xB30B1222)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: connected ? BrandDesktopColors.success.withValues(alpha: .28) : BrandDesktopColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 46, dark: true),
              const Spacer(),
              DesktopStatusPill(label: status.label, color: status.color, icon: status.icon),
            ],
          ),
          const Spacer(),
          Center(child: _DesktopPowerButton(state: state)),
          const Spacer(),
          Text(
            connected
                ? '加速已开启'
                : busy
                ? '正在建立连接'
                : state.phase == ClientConnectionPhase.loggedOut
                ? '登录后即可加速'
                : '准备就绪',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: BrandDesktopColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Gap(8),
          Text(
            connected ? '当前线路 $nodeName 运行稳定' : '选择可用节点后，点击按钮开始加速',
            style: theme.textTheme.bodyMedium?.copyWith(color: BrandDesktopColors.textSecondary),
          ),
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
        ? BrandDesktopColors.success
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
              duration: const Duration(milliseconds: 220),
              width: 178,
              height: 178,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: connected ? BrandDesktopGradients.connected : BrandDesktopGradients.primary,
                boxShadow: BrandDesktopShadows.glow(color, alpha: state.canTap ? .26 : .10),
              ),
              child: Center(
                child: busy
                    ? const SizedBox.square(
                        dimension: 38,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : Icon(connected ? Icons.stop_rounded : Icons.bolt_rounded, color: Colors.white, size: 70),
              ),
            ),
          ),
          const Gap(20),
          Text(
            state.buttonLabel,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: BrandDesktopColors.textPrimary, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _HomeSideCards extends ConsumerWidget {
  const _HomeSideCards({required this.node, required this.nodeName, required this.connected});

  final ClientNode? node;
  final String nodeName;
  final bool connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = node?.delay;
    final delayText = delay == null || delay == 0
        ? '待测速'
        : delay > 65000
        ? '不可用'
        : '$delay ms';
    final stats = connected ? ref.watch(statsNotifierProvider).valueOrNull : null;
    final usedBytes = connected ? ((stats?.uplinkTotal.toInt() ?? 0) + (stats?.downlinkTotal.toInt() ?? 0)) : 0;

    return Column(
      children: [
        DesktopMetricTile(icon: Icons.hub_rounded, label: '当前节点', value: nodeName, accent: BrandDesktopColors.cyan),
        const Gap(16),
        DesktopMetricTile(icon: Icons.speed_rounded, label: '节点延迟', value: delayText, accent: _delayColor(delay)),
        const Gap(16),
        DesktopMetricTile(
          icon: Icons.data_usage_rounded,
          label: '今日流量',
          value: usedBytes.sizeGB(),
          accent: BrandDesktopColors.accent,
        ),
        const Gap(16),
        SizedBox(
          height: 220,
          child: DesktopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DesktopIconBox(icon: Icons.verified_user_rounded, selected: true),
                const Spacer(),
                Text(
                  '商业级体验',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: BrandDesktopColors.textPrimary),
                ),
                const Gap(8),
                Text('普通界面仅展示必要状态，不暴露协议、端口或订阅信息。', style: Theme.of(context).textTheme.bodyMedium),
              ],
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

String _safeNodeName(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'https?://[^\s]+'), '***')
      .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '***')
      .replaceAll(RegExp(r'\b[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:\d+)?\b'), '***');
  return sanitized.trim().isEmpty ? '暂无可用节点' : sanitized;
}

class _StatusInfo {
  const _StatusInfo(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}
