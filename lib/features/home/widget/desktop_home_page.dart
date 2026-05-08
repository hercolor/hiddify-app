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
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DesktopHomePage extends HookConsumerWidget {
  const DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientConnectionStateProvider);
    final nodeSelection = ref.watch(clientNodeSelectionProvider);
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final selectedNode = nodeSelection.valueOrNull?.selectedNode;
    final nodeName = nodeSelection.when(
      data: (selection) => safeNodeDisplayName(
        selection.selectedNode?.name ?? (selection.nodes.isNotEmpty ? selection.nodes.first.name : null),
        fallback: '暂无可用节点',
      ),
      error: (_, _) => '暂无可用节点',
      loading: () => '读取线路中',
    );

    return DesktopPageScaffold(
      title: '4376 VPN',
      actions: const [_TopRoundIcon(icon: Icons.workspace_premium_outlined)],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SpeedCard(
                  label: '下载速率',
                  value: stats.downlink.toInt().speed(),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const Gap(14),
              Expanded(
                child: _SpeedCard(label: '上传速率', value: stats.uplink.toInt().speed(), icon: Icons.arrow_upward_rounded),
              ),
            ],
          ),
          const Gap(18),
          Expanded(child: _ConnectionHero(state: state)),
          const Gap(16),
          _HomeNodeCard(node: selectedNode, nodeName: nodeName),
          const Gap(14),
          const _RouteModeSegmentedControl(),
        ],
      ),
    );
  }
}

class _TopRoundIcon extends StatelessWidget {
  const _TopRoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: BrandDesktopColors.cardSolid,
        shape: BoxShape.circle,
        border: Border.all(color: BrandDesktopColors.border, width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: BrandDesktopColors.textPrimary, size: 22),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DesktopCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderColor: const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: BrandDesktopColors.textMuted),
              const Gap(6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: BrandDesktopColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Gap(12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: BrandDesktopColors.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero({required this.state});

  final ClientConnectionState state;

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo(state);
    final connected = state.phase == ClientConnectionPhase.connected;
    final busy = state.isBusy;
    return DesktopCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderColor: connected ? BrandDesktopColors.accent.withOpacity(.22) : const Color(0xFFF1F5F9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            status.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: connected ? BrandDesktopColors.accent : BrandDesktopColors.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const Gap(12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: connected ? BrandDesktopColors.accent.withOpacity(.08) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              connected
                  ? '已保护您的网络连接'
                  : busy
                  ? '正在建立安全连接'
                  : state.phase == ClientConnectionPhase.loggedOut
                  ? '登录后开启加速服务'
                  : '畅享 VIP 高速专线',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: connected ? BrandDesktopColors.accent : BrandDesktopColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          _DesktopPowerButton(state: state),
          const Spacer(),
          Text(
            connected ? '点击停止加速' : state.buttonLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: connected ? BrandDesktopColors.accent : BrandDesktopColors.textSecondary,
              fontWeight: FontWeight.w900,
            ),
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
        ? BrandDesktopColors.accent
        : failed
        ? BrandDesktopColors.error
        : busy
        ? BrandDesktopColors.warning
        : BrandDesktopColors.textMuted;
    return Semantics(
      button: true,
      enabled: state.canTap,
      label: state.buttonLabel,
      child: InkWell(
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
        child: SizedBox.square(
          dimension: 238,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 238,
                height: 238,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected
                      ? BrandDesktopColors.accent.withOpacity(.08)
                      : const Color(0xFFE2E8F0).withOpacity(.18),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 198,
                height: 198,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected
                      ? BrandDesktopColors.accent.withOpacity(.15)
                      : const Color(0xFFE2E8F0).withOpacity(.38),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: connected
                      ? const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: Border.all(color: connected ? Colors.transparent : const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: connected ? const Color(0xFF1D4ED8).withOpacity(.38) : Colors.black.withOpacity(.08),
                      blurRadius: connected ? 30 : 20,
                      spreadRadius: connected ? 8 : 0,
                      offset: const Offset(0, 10),
                    ),
                    if (busy)
                      BoxShadow(color: BrandDesktopColors.warning.withOpacity(.18), blurRadius: 34, spreadRadius: 3),
                  ],
                ),
                child: Center(
                  child: busy
                      ? CircularProgressIndicator(strokeWidth: 3, color: color)
                      : Icon(
                          connected ? Icons.shield_rounded : Icons.power_settings_new_rounded,
                          color: connected ? Colors.white : color,
                          size: 58,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNodeCard extends StatelessWidget {
  const _HomeNodeCard({required this.node, required this.nodeName});

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
    final delayColor = _delayColor(delay);
    return DesktopCard(
      padding: const EdgeInsets.all(20),
      borderColor: const Color(0xFFF1F5F9),
      onTap: () => context.goNamed('proxies'),
      child: Row(
        children: [
          _DesktopNodeFlag(nodeName: nodeName),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前节点',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: BrandDesktopColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(5),
                Text(
                  nodeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: BrandDesktopColors.textPrimary, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const Gap(10),
          DesktopStatusPill(label: delayText, color: delayColor, icon: Icons.speed_rounded),
          const Gap(6),
          const Icon(Icons.chevron_right_rounded, color: BrandDesktopColors.textMuted),
        ],
      ),
    );
  }
}

class _DesktopNodeFlag extends StatelessWidget {
  const _DesktopNodeFlag({required this.nodeName});

  final String nodeName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          _nodeFlagFor(nodeName),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: BrandDesktopColors.textPrimary),
        ),
      ),
    );
  }
}

class _RouteModeSegmentedControl extends ConsumerWidget {
  const _RouteModeSegmentedControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGlobalMode = ref.watch(ConfigOptions.globalRouteMode);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RouteModeChoice(
              selected: !isGlobalMode,
              icon: Icons.alt_route_rounded,
              title: '自动',
              subtitle: '智能路由',
              onTap: () => ref.read(ConfigOptions.globalRouteMode.notifier).update(false),
            ),
          ),
          Expanded(
            child: _RouteModeChoice(
              selected: isGlobalMode,
              icon: Icons.public_rounded,
              title: '全局',
              subtitle: '全部流量',
              onTap: () => ref.read(ConfigOptions.globalRouteMode.notifier).update(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteModeChoice extends StatelessWidget {
  const _RouteModeChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BrandDesktopColors.accent : BrandDesktopColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? BrandDesktopColors.accent.withOpacity(.20) : Colors.transparent),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const Gap(8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w900),
              ),
              const Gap(2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? BrandDesktopColors.accent.withOpacity(.80) : BrandDesktopColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_StatusInfo _statusInfo(ClientConnectionState state) {
  return switch (state.phase) {
    ClientConnectionPhase.connected => const _StatusInfo('已连接', BrandDesktopColors.accent, Icons.check_circle_rounded),
    ClientConnectionPhase.connecting ||
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission => const _StatusInfo(
      '正在连接',
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
    ClientConnectionPhase.loggedOut => const _StatusInfo(
      '未登录',
      BrandDesktopColors.textPrimary,
      Icons.person_off_rounded,
    ),
    ClientConnectionPhase.initializing => const _StatusInfo(
      '初始化中',
      BrandDesktopColors.textSecondary,
      Icons.hourglass_top_rounded,
    ),
    _ => const _StatusInfo('未连接', BrandDesktopColors.textPrimary, Icons.radio_button_unchecked_rounded),
  };
}

Color _delayColor(int? delay) {
  if (delay == null || delay == 0) return BrandDesktopColors.textMuted;
  if (delay < 800) return BrandDesktopColors.success;
  if (delay < 1500) return BrandDesktopColors.warning;
  return BrandDesktopColors.error;
}

String _nodeFlagFor(String name) {
  if (name.contains('香港')) return 'HK';
  if (name.contains('台湾') || name.contains('台灣')) return 'TW';
  if (name.contains('日本') || name.contains('东京') || name.contains('東京')) return 'JP';
  if (name.contains('新加坡')) return 'SG';
  if (name.contains('美国') || name.contains('美國') || name.contains('洛杉矶') || name.contains('洛杉磯')) return 'US';
  if (name.contains('英国') || name.contains('英國') || name.contains('伦敦') || name.contains('倫敦')) return 'UK';
  if (name.contains('韩国') || name.contains('韓國') || name.contains('首尔') || name.contains('首爾')) return 'KR';
  if (name.contains('德国') || name.contains('德國')) return 'DE';
  if (name.contains('法国') || name.contains('法國')) return 'FR';
  return 'GL';
}

class _StatusInfo {
  const _StatusInfo(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}
