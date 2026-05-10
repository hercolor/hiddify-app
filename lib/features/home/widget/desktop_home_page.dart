import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
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
    final nodeName = nodeSelection.when(
      data: (selection) => safeNodeDisplayName(
        selection.selectedNode?.name ?? (selection.nodes.isNotEmpty ? selection.nodes.first.name : null),
        fallback: '暂无可用节点',
      ),
      error: (_, _) => '暂无可用节点',
      loading: () => '读取线路中',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TopRoundIcon(icon: Icons.settings_outlined, onTap: () => context.pushNamed('settings')),
                  const Text(
                    '4376 VPN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  _TopRoundIcon(
                    icon: Icons.workspace_premium_outlined,
                    onTap: () => context.pushNamed('premiumRenewal'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SpeedCard(
                          label: '下载速率',
                          value: stats.downlink.toInt().speed(),
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: _SpeedCard(
                          label: '上传速率',
                          value: stats.uplink.toInt().speed(),
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ),
                    ],
                  ),
                  const Gap(48),
                  _ConnectionHero(state: state),
                  const Gap(64),
                  _HomeNodeCard(nodeName: nodeName),
                  const Gap(24),
                  const _RouteModeSegmentedControl(),
                  const Gap(48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRoundIcon extends StatelessWidget {
  const _TopRoundIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF0F172A), size: 22),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
              const Gap(6),
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Gap(12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF0F172A),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(32)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            status.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              color: connected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const Gap(12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: connected ? const Color(0xFF2563EB).withOpacity(.08) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
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
              style: TextStyle(
                fontSize: 13,
                color: connected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Gap(48),
          _DesktopPowerButton(state: state),
          const Gap(48),
          Text(
            connected ? '点击停止加速' : state.buttonLabel,
            style: TextStyle(
              fontSize: 14,
              color: connected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPowerButton extends ConsumerStatefulWidget {
  const _DesktopPowerButton({required this.state});

  final ClientConnectionState state;

  @override
  ConsumerState<_DesktopPowerButton> createState() => _DesktopPowerButtonState();
}

class _DesktopPowerButtonState extends ConsumerState<_DesktopPowerButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    if (widget.state.isBusy) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _DesktopPowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isBusy && !oldWidget.state.isBusy) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.state.isBusy && oldWidget.state.isBusy) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.state.phase == ClientConnectionPhase.connected;
    final busy = widget.state.isBusy;
    final failed = widget.state.phase == ClientConnectionPhase.failed;
    final color = connected
        ? const Color(0xFF2563EB)
        : failed
        ? const Color(0xFFEF4444)
        : busy
        ? const Color(0xFFF59E0B)
        : const Color(0xFF94A3B8);

    return Semantics(
      button: true,
      enabled: widget.state.canTap,
      label: widget.state.buttonLabel,
      child: GestureDetector(
        onTap: widget.state.canTap
            ? () async {
                if (widget.state.phase == ClientConnectionPhase.loggedOut) {
                  ref.read(connectionNotifierProvider.notifier).connectRequested();
                  if (context.mounted) context.goNamed('settings');
                  return;
                }
                await ref.read(connectionNotifierProvider.notifier).connectRequested();
              }
            : null,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: busy ? _pulseAnimation.value * 1.2 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected
                            ? const Color(0xFF2563EB).withOpacity(.08)
                            : const Color(0xFFE2E8F0).withOpacity(.20),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: busy ? _pulseAnimation.value * 1.1 : 1.0,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected
                            ? const Color(0xFF2563EB).withOpacity(.15)
                            : const Color(0xFFE2E8F0).withOpacity(.40),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
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
                          color: connected
                              ? const Color(0xFF1D4ED8).withOpacity(.4)
                              : const Color(0xFF0F172A).withOpacity(.08),
                          blurRadius: connected ? 30 : 20,
                          spreadRadius: connected ? 8 : 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: busy
                          ? CircularProgressIndicator(strokeWidth: 3, color: color)
                          : Icon(
                              connected ? Icons.shield_rounded : Icons.power_settings_new_rounded,
                              color: connected ? Colors.white : color,
                              size: 56,
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeNodeCard extends StatelessWidget {
  const _HomeNodeCard({required this.nodeName});

  final String nodeName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.goNamed('proxies'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            _DesktopNodeFlag(nodeName: nodeName),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前节点',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const Gap(4),
                  Text(
                    nodeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            const Gap(10),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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
    final color = selected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(.06), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
          border: Border.all(color: selected ? const Color(0xFF2563EB).withOpacity(.2) : Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const Gap(8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
            const Gap(2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? const Color(0xFF2563EB).withOpacity(.80) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_StatusInfo _statusInfo(ClientConnectionState state) {
  return switch (state.phase) {
    ClientConnectionPhase.connected => const _StatusInfo('已连接', Color(0xFF2563EB), Icons.check_circle_rounded),
    ClientConnectionPhase.connecting ||
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission => const _StatusInfo(
      '正在连接...',
      Color(0xFFF59E0B),
      Icons.sync_rounded,
    ),
    ClientConnectionPhase.reconnecting => const _StatusInfo('重连中...', Color(0xFFF59E0B), Icons.restart_alt_rounded),
    ClientConnectionPhase.stopping => const _StatusInfo('停止中...', Color(0xFFF59E0B), Icons.power_settings_new_rounded),
    ClientConnectionPhase.failed => const _StatusInfo('连接异常', Color(0xFFEF4444), Icons.error_rounded),
    ClientConnectionPhase.loggedOut => const _StatusInfo('未登录', Color(0xFF0F172A), Icons.person_off_rounded),
    ClientConnectionPhase.initializing => const _StatusInfo('初始化中...', Color(0xFF64748B), Icons.hourglass_top_rounded),
    _ => const _StatusInfo('未连接', Color(0xFF0F172A), Icons.radio_button_unchecked_rounded),
  };
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
