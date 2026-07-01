import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/dev_mode/dev_mode_providers.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MobileHomePage extends HookConsumerWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDevMode = ref.watch(devModeProvider);
    final state = isDevMode ? ref.watch(mockClientConnectionStateProvider) : ref.watch(clientConnectionStateProvider);
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();

    late final String nodeName;
    late final ClientNode? selectedNode;
    late final List<ClientNode> nodes;

    if (isDevMode) {
      final mockSelection = ref.watch(mockClientNodeSelectionProvider);
      selectedNode = mockSelection.selectedNode;
      nodes = mockSelection.nodes;
      nodeName = safeNodeDisplayName(
        selectedNode?.name ?? (nodes.isNotEmpty ? nodes.first.name : null),
        fallback: '暂无可用节点',
      );
    } else {
      final nodeSelection = ref.watch(clientNodeSelectionProvider);
      nodeName = nodeSelection.when(
        data: (sel) => safeNodeDisplayName(
          sel.selectedNode?.name ?? (sel.nodes.isNotEmpty ? sel.nodes.first.name : null),
          fallback: '暂无可用节点',
        ),
        error: (_, _) => '暂无可用节点',
        loading: () => '读取线路中',
      );
      final selection = nodeSelection.valueOrNull;
      selectedNode = selection?.selectedNode;
      nodes = selection?.nodes ?? [];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: const _MobileHeader(),
            ),
            const Spacer(flex: 1),
            // Connection button area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _MobileConnectionHero(state: state, stats: stats, isDevMode: isDevMode),
            ),
            const Spacer(flex: 1),
            // Node card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _MobileNodeCard(nodeName: nodeName, isDevMode: isDevMode),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/images/app_icon.png', width: 40, height: 40, fit: BoxFit.cover),
            ),
            const Gap(10),
            Image.asset('assets/images/logo_text.png', width: 120, height: 36, fit: BoxFit.contain),
          ],
        ),
        GestureDetector(
          onTap: () => context.pushNamed('diagnostics'),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CONNECTION HERO (Mobile version - smaller)
// ============================================================

class _MobileConnectionHero extends StatelessWidget {
  const _MobileConnectionHero({required this.state, required this.stats, required this.isDevMode});
  final ClientConnectionState state;
  final SystemInfo stats;
  final bool isDevMode;

  @override
  Widget build(BuildContext context) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final failed = state.phase == ClientConnectionPhase.failed;
    final busy = state.isBusy;
    final loggedOut = state.phase == ClientConnectionPhase.loggedOut;

    return Column(
      children: [
        // Status chip
        _MobileStatusChip(state: state),
        const Gap(20),
        // Connection button
        _MobileConnectButton(state: state, isDevMode: isDevMode),
        const Gap(16),
        // Status text
        Text(
          connected
              ? '已连接'
              : busy
              ? '正在连接...'
              : failed
              ? '连接失败'
              : loggedOut
              ? '未登录'
              : '未连接',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: connected
                ? BrandColors.signalBlue
                : failed
                ? BrandColors.error
                : const Color(0xFF64748B),
          ),
        ),
        const Gap(4),
        Text(
          connected
              ? '您的网络连接已安全加密'
              : busy
              ? '正在建立安全通道'
              : failed
              ? '请检查网络后重试'
              : loggedOut
              ? '登录账号后开启加速'
              : '点击按钮一键连接',
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        // Speed display when connected
        if (connected) ...[
          const Gap(12),
          _MobileSpeedRow(download: stats.downlink.toInt().speed(), upload: stats.uplink.toInt().speed()),
        ],
      ],
    );
  }
}

class _MobileStatusChip extends StatelessWidget {
  const _MobileStatusChip({required this.state});
  final ClientConnectionState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final failed = state.phase == ClientConnectionPhase.failed;

    final (String label, Color color, IconData icon) = connected
        ? ('已保护', BrandColors.signalBlue, Icons.verified_user_rounded)
        : state.isBusy
        ? ('连接中', BrandColors.warning, Icons.sync_rounded)
        : failed
        ? ('失败', BrandColors.error, Icons.error_outline_rounded)
        : ('空闲', const Color(0xFF94A3B8), Icons.wifi_off_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: connected ? BrandColors.signalBlue.withOpacity(.1) : failed ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected ? BrandColors.signalBlue.withOpacity(.3) : failed ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const Gap(6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _MobileConnectButton extends ConsumerWidget {
  const _MobileConnectButton({required this.state, required this.isDevMode});
  final ClientConnectionState state;
  final bool isDevMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final busy = state.isBusy;
    final failed = state.phase == ClientConnectionPhase.failed;
    final loggedOut = state.phase == ClientConnectionPhase.loggedOut;

    final color = connected
        ? BrandColors.signalBlue
        : failed
        ? BrandColors.error
        : loggedOut
        ? BrandColors.subtle
        : BrandColors.signalBlue;

    return GestureDetector(
      onTap: state.canTap
          ? () async {
              if (loggedOut) {
                context.goNamed('membership');
                return;
              }
              await ref.read(connectionNotifierProvider.notifier).connectRequested();
            }
          : null,
      child: AnimatedScale(
        scale: busy || connected ? 1.0 : 0.98,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? BrandColors.signalBlue : Colors.white,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(connected ? .3 : .15),
                blurRadius: 30,
                spreadRadius: connected ? 5 : 0,
                offset: const Offset(0, 8),
              ),
              if (busy)
                BoxShadow(
                  color: color.withOpacity(.2),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
            ],
          ),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: connected ? Colors.white : color,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    connected ? Icons.check_rounded : Icons.power_settings_new_rounded,
                    size: 56,
                    color: connected ? Colors.white : color,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MobileSpeedRow extends StatelessWidget {
  const _MobileSpeedRow({required this.download, required this.upload});
  final String download;
  final String upload;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SpeedItem(icon: Icons.arrow_downward_rounded, label: download, color: BrandColors.signalBlue),
        const Gap(24),
        _SpeedItem(icon: Icons.arrow_upward_rounded, label: upload, color: const Color(0xFF10B981)),
      ],
    );
  }
}

class _SpeedItem extends StatelessWidget {
  const _SpeedItem({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const Gap(4),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ============================================================
// NODE CARD (Mobile version)
// ============================================================

class _MobileNodeCard extends StatelessWidget {
  const _MobileNodeCard({required this.nodeName, required this.isDevMode});
  final String nodeName;
  final bool isDevMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.goNamed('proxies'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: BrandColors.signalBlue.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.language_rounded, size: 20, color: BrandColors.signalBlue),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('当前节点', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  const Gap(2),
                  Text(
                    nodeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
