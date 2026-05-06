import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/brand_mark.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/home/widget/desktop_home_page.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
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
      data: (selection) => selection.selectedNode?.name ?? '暂无可用节点',
      error: (_, _) => '暂无可用节点',
      loading: () => '读取线路中',
    );
    final delay = _resolveDelay(selectedNode);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 76,
        title: const BrandMark(size: 34),
        actions: const [Padding(padding: EdgeInsetsDirectional.only(end: 20), child: AppVersionLabel())],
      ),
      body: BrandScaffoldBackground(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(BrandSpacing.page, 8, BrandSpacing.page, 104),
                children: [
                  _StatusHero(state: clientState),
                  const Gap(24),
                  const Center(child: ConnectionButton()),
                  const Gap(28),
                  _NodeCard(nodeName: nodeName, delay: delay),
                  const Gap(14),
                  _TodayTrafficCard(connected: clientState.phase == ClientConnectionPhase.connected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int? _resolveDelay(ClientNode? selectedNode) => selectedNode?.delay;

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.state});

  final ClientConnectionState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final busy = state.isBusy;
    final theme = Theme.of(context);
    final label = switch (state.phase) {
      ClientConnectionPhase.connected => '已连接',
      ClientConnectionPhase.initializing => '初始化中',
      ClientConnectionPhase.loggedOut => '未登录',
      ClientConnectionPhase.failed => '连接异常',
      ClientConnectionPhase.preparing ||
      ClientConnectionPhase.requestingVpnPermission ||
      ClientConnectionPhase.connecting ||
      ClientConnectionPhase.reconnecting => '连接中',
      _ => '未连接',
    };
    final color = connected
        ? BrandColors.success
        : busy
        ? BrandColors.signalBlue
        : state.phase == ClientConnectionPhase.failed
        ? BrandColors.error
        : BrandColors.muted;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.card.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(BrandRadii.xl),
        border: Border.all(color: BrandColors.border),
        boxShadow: BrandShadows.card,
      ),
      child: Row(
        children: [
          BrandIcon(size: 52, selected: connected || busy),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('连接状态', style: theme.textTheme.bodySmall?.copyWith(color: BrandColors.muted)),
                const Gap(4),
                Text(label, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: .20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const Gap(6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
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

    return _BrandInfoCard(
      icon: Icons.hub_rounded,
      title: '当前节点',
      value: nodeName,
      trailing: delayText,
      trailingColor: delay != null && delay! > 0 && delay! < 800 ? BrandColors.success : BrandColors.muted,
      footer: Text('仅显示节点名称，保护连接信息', style: theme.textTheme.bodySmall),
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
    return _BrandInfoCard(
      icon: Icons.data_usage_rounded,
      title: '今日流量',
      value: used,
      trailing: '实时',
      trailingColor: BrandColors.signalBlue,
      footer: const _MiniWave(),
    );
  }
}

class _BrandInfoCard extends StatelessWidget {
  const _BrandInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.trailing,
    required this.trailingColor,
    required this.footer,
  });

  final IconData icon;
  final String title;
  final String value;
  final String trailing;
  final Color trailingColor;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BrandColors.card,
        borderRadius: BorderRadius.circular(BrandRadii.lg),
        border: Border.all(color: BrandColors.border),
        boxShadow: BrandShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrandIcon(size: 42, icon: icon),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodySmall?.copyWith(color: BrandColors.muted)),
                    const Gap(3),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: trailingColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(trailing, style: theme.textTheme.labelMedium?.copyWith(color: trailingColor)),
              ),
            ],
          ),
          const Gap(14),
          footer,
        ],
      ),
    );
  }
}

class _MiniWave extends StatelessWidget {
  const _MiniWave();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: CustomPaint(painter: _MiniWavePainter()),
    );
  }
}

class _MiniWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = BrandGradients.primary.createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(0, size.height * .64);
    for (var i = 0; i <= 6; i++) {
      final x = size.width * (i + 1) / 7;
      final y = size.height * (.58 - (i.isEven ? .18 : -.10));
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: '版本',
      button: false,
      child: Container(
        decoration: BoxDecoration(color: BrandColors.mistBlue, borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(color: BrandColors.signalBlue, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
