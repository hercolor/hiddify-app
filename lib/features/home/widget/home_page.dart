import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/home/widget/desktop_home_page.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isWindows) return const DesktopHomePage();

    final clientState = ref.watch(clientConnectionStateProvider);
    final nodeSelection = ref.watch(clientNodeSelectionProvider);
    final selectedNode = nodeSelection.valueOrNull?.selectedNode;
    final nodeName = nodeSelection.when(
      data: (selection) => safeNodeDisplayName(selection.selectedNode?.name, fallback: '暂无可用节点'),
      error: (_, _) => '暂无可用节点',
      loading: () => '读取线路中',
    );
    final delay = _resolveDelay(selectedNode);
    final connected = clientState.phase == ClientConnectionPhase.connected;

    return Scaffold(
      extendBody: true,
      body: BrandScaffoldBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                child: Column(
                  children: [
                    _HomeHeader(connected: connected),
                    Expanded(child: _ConnectionFocus(state: clientState)),
                    _NodeCard(nodeName: nodeName, delay: delay),
                    const Gap(12),
                    _TodayTrafficCard(connected: clientState.phase == ClientConnectionPhase.connected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int? _resolveDelay(ClientNode? selectedNode) => selectedNode?.delay;

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '4376',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: BrandColors.slate,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        Icon(Icons.security_rounded, color: connected ? BrandColors.signalBlue : BrandColors.subtle),
      ],
    );
  }
}

class _ConnectionFocus extends StatelessWidget {
  const _ConnectionFocus({required this.state});

  final ClientConnectionState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final busy = state.isBusy;
    final theme = Theme.of(context);
    final label = switch (state.phase) {
      ClientConnectionPhase.connected => '已受保护',
      ClientConnectionPhase.initializing => '初始化中',
      ClientConnectionPhase.loggedOut => '未登录',
      ClientConnectionPhase.failed => '连接异常',
      ClientConnectionPhase.preparing ||
      ClientConnectionPhase.requestingVpnPermission ||
      ClientConnectionPhase.connecting ||
      ClientConnectionPhase.reconnecting => '连接中',
      ClientConnectionPhase.stopping => '正在停止',
      _ => '尚未连接',
    };
    final helper = connected
        ? '连接稳定，正在保护您的网络'
        : busy
        ? '正在建立安全连接'
        : '点击按钮以保护您的隐私';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: connected ? BrandColors.signalBlue : BrandColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(8),
          Text(
            helper,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: BrandColors.muted),
          ),
          const Gap(64),
          const ConnectionButton(),
        ],
      ),
    );
  }
}

class _DemoNodeIcon extends StatelessWidget {
  const _DemoNodeIcon({this.icon = Icons.hub_rounded});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: BrandColors.mist, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: BrandColors.signalBlue, size: 22),
    );
  }
}

class _DemoDelayPill extends StatelessWidget {
  const _DemoDelayPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: BrandColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 10, offset: const Offset(0, 4)),
          BoxShadow(color: BrandColors.signalBlue.withValues(alpha: .04), blurRadius: 24, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: BrandColors.border.withValues(alpha: .72)),
      ),
      child: child,
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.nodeName, this.delay});

  final String nodeName;
  final int? delay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delayText = delay == null || delay == 0
        ? '待测速'
        : delay! > 65000
        ? '延迟不可用'
        : '$delay ms';

    final delayColor = delay != null && delay! > 0 && delay! < 800 ? BrandColors.success : BrandColors.muted;
    return _DemoCard(
      child: Row(
        children: [
          const _DemoNodeIcon(),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nodeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Gap(4),
                Text('当前节点', style: theme.textTheme.bodySmall?.copyWith(color: BrandColors.muted)),
              ],
            ),
          ),
          _DemoDelayPill(label: delayText, color: delayColor),
          const Gap(8),
          const Icon(Icons.chevron_right_rounded, color: BrandColors.subtle),
        ],
      ),
    );
  }
}

class _TodayTrafficCard extends ConsumerWidget {
  const _TodayTrafficCard({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = connected ? ref.watch(statsNotifierProvider).valueOrNull : null;
    final usedBytes = connected ? ((stats?.uplinkTotal.toInt() ?? 0) + (stats?.downlinkTotal.toInt() ?? 0)) : 0;
    final used = usedBytes.sizeGB();
    return _DemoCard(
      child: Row(
        children: [
          const _DemoNodeIcon(icon: Icons.data_usage_rounded),
          const Gap(16),
          Expanded(child: Text('今日流量', style: Theme.of(context).textTheme.bodyMedium)),
          Text(used, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
