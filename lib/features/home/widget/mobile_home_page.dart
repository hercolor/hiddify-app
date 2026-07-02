import 'package:circle_flags/circle_flags.dart';
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
import 'package:hiddify/features/settings/data/config_option_repository.dart';
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
      backgroundColor: const Color(0xFFEDF2FA),
      body: Stack(
        children: [
          // Decorative background orbs
          Positioned(
            top: 80,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BrandDesktopColors.accent.withOpacity(.06),
                    BrandDesktopColors.accent.withOpacity(.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BrandDesktopColors.cyan.withOpacity(.08),
                    BrandDesktopColors.cyan.withOpacity(.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: const _MobileHeader(),
                ),
                const Spacer(flex: 2),
                // Connection hero with gradient card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MobileConnectionHero(state: state, stats: stats, isDevMode: isDevMode),
                ),
                const Spacer(flex: 3),
                // Node card with flag
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _MobileNodeCard(nodeName: nodeName, isDevMode: isDevMode),
                ),
                const Spacer(flex: 1),
                // Route toggle
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: const _RouteToggle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER (mobile - keeps settings button)
// ============================================================

class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/app_icon.png', width: 40, height: 40, fit: BoxFit.cover),
        ),
        const Gap(10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(-10, 2),
              child: Image.asset('assets/images/logo_text.png', width: 120, height: 36, fit: BoxFit.contain),
            ),
            const Gap(1),
            const Text(
              'Fast, Stable & Secure',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// CONNECTION HERO (with gradient card + butterfly + animation)
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connected
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF4338CA)]
              : failed
              ? [const Color(0xFFFFF5F5), const Color(0xFFFFF1F1)]
              : [const Color(0xFFF8FAFF), const Color(0xFFEEF4FF)],
          stops: connected ? const [0.0, 0.4, 1.0] : null,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: connected
                ? const Color(0xFF4338CA).withOpacity(.30)
                : failed
                ? const Color(0xFFF87171).withOpacity(.10)
                : const Color(0xFF64748B).withOpacity(.12),
            blurRadius: 40,
            spreadRadius: connected ? 2 : 0,
            offset: const Offset(0, 16),
          ),
          if (connected)
            BoxShadow(
              color: BrandDesktopColors.accent.withOpacity(.12),
              blurRadius: 60,
              spreadRadius: 3,
              offset: const Offset(0, 22),
            ),
        ],
      ),
      child: Column(
        children: [
          const Gap(22),
          // Status chip
          _MobileStatusChip(state: state),
          const Gap(18),
          // Butterfly connect button with pulse animation
          _MobileConnectButton(state: state, isDevMode: isDevMode),
          const Gap(14),
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: connected
                  ? Colors.white
                  : failed
                  ? const Color(0xFFDC2626)
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: connected
                  ? Colors.white54
                  : failed
                  ? const Color(0xFFF87171)
                  : const Color(0xFF94A3B8),
            ),
          ),
          // Speed display when connected
          if (connected) ...[
            const Gap(18),
            _MobileSpeedRow(download: stats.downlink.toInt().speed(), upload: stats.uplink.toInt().speed()),
          ],
          const Gap(10),
        ],
      ),
    );
  }
}

// ============================================================
// STATUS CHIP
// ============================================================

class _MobileStatusChip extends StatelessWidget {
  const _MobileStatusChip({required this.state});
  final ClientConnectionState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final failed = state.phase == ClientConnectionPhase.failed;

    final (String label, Color color, IconData icon) = connected
        ? ('已保护', const Color(0xFF3B82F6), Icons.verified_user_rounded)
        : state.isBusy
        ? ('连接中', const Color(0xFFF59E0B), Icons.sync_rounded)
        : failed
        ? ('失败', const Color(0xFFEF4444), Icons.error_outline_rounded)
        : ('空闲', const Color(0xFF94A3B8), Icons.wifi_off_rounded);

    final bool dark = connected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? BrandDesktopColors.accent.withOpacity(.25)
            : failed
            ? const Color(0xFFFFF5F5)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: dark
            ? Border.all(color: BrandDesktopColors.accent.withOpacity(.45))
            : failed
            ? Border.all(color: const Color(0xFFFECACA))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: dark ? Colors.white : color),
          const Gap(6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: dark ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BUTTERFLY CONNECT BUTTON with pulse animation
// ============================================================

class _MobileConnectButton extends ConsumerStatefulWidget {
  const _MobileConnectButton({required this.state, required this.isDevMode});
  final ClientConnectionState state;
  final bool isDevMode;

  @override
  ConsumerState<_MobileConnectButton> createState() => _MobileConnectButtonState();
}

class _MobileConnectButtonState extends ConsumerState<_MobileConnectButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulseOuter;
  late Animation<double> _pulseInner;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _pulseOuter = Tween(begin: 0.9, end: 1.12).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, .5, curve: Curves.easeOut)),
    );
    _pulseInner = Tween(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(.2, .7, curve: Curves.easeOut)),
    );
    if (widget.state.isBusy || widget.state.phase == ClientConnectionPhase.connected) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _MobileConnectButton old) {
    super.didUpdateWidget(old);
    final shouldAnimate = widget.state.isBusy || widget.state.phase == ClientConnectionPhase.connected;
    final wasAnimating = old.state.isBusy || old.state.phase == ClientConnectionPhase.connected;
    if (shouldAnimate && !wasAnimating) _ctrl.repeat(reverse: true);
    if (!shouldAnimate && wasAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.state.phase == ClientConnectionPhase.connected;
    final failed = widget.state.phase == ClientConnectionPhase.failed;
    final loggedOut = widget.state.phase == ClientConnectionPhase.loggedOut;

    final Color accent = connected
        ? Colors.white
        : failed
        ? const Color(0xFFF87171)
        : BrandDesktopColors.accent;
    final Color fill = connected
        ? Colors.white
        : failed
        ? const Color(0xFFF87171)
        : BrandDesktopColors.accent;

    return Semantics(
      button: true,
      enabled: widget.state.canTap,
      child: GestureDetector(
        onTap: widget.state.canTap
            ? () async {
                if (widget.isDevMode) {
                  final mockNotifier = ref.read(mockClientConnectionStateProvider.notifier);
                  if (widget.state.phase == ClientConnectionPhase.connected) {
                    mockNotifier.disconnect();
                  } else {
                    mockNotifier.connect();
                    await Future.delayed(const Duration(milliseconds: 1500));
                    mockNotifier.connected();
                  }
                  return;
                }
                if (loggedOut) {
                  if (context.mounted) context.goNamed('membership');
                  return;
                }
                await ref.read(connectionNotifierProvider.notifier).connectRequested();
              }
            : null,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            return SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Radial glow (connected)
                  if (connected)
                    Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            BrandDesktopColors.accent.withOpacity(.20),
                            BrandDesktopColors.accent.withOpacity(.06),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  // Pulse rings
                  if (connected || widget.state.isBusy)
                    Transform.scale(
                      scale: _pulseOuter.value,
                      child: Container(
                        width: 114,
                        height: 114,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent.withOpacity(.15), width: 2.5),
                        ),
                      ),
                    ),
                  if (connected || widget.state.isBusy)
                    Transform.scale(
                      scale: _pulseInner.value,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent.withOpacity(.25), width: 2),
                        ),
                      ),
                    ),
                  // Main circle with butterfly
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      boxShadow: [
                        BoxShadow(
                          color: fill.withOpacity(.45),
                          blurRadius: 30,
                          spreadRadius: connected ? 6 : 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.state.isBusy
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation(
                                  connected ? BrandDesktopColors.accent : Colors.white,
                                ),
                              ),
                            )
                          : ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                connected ? BrandDesktopColors.accent : Colors.white,
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(
                                connected
                                    ? 'assets/images/butterfly_filled.png'
                                    : 'assets/images/butterfly_outline.png',
                                width: 90,
                                height: 90,
                              ),
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

// ============================================================
// SPEED ROW
// ============================================================

class _MobileSpeedRow extends StatelessWidget {
  const _MobileSpeedRow({required this.download, required this.upload});
  final String download;
  final String upload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _SpeedTile(icon: Icons.arrow_downward_rounded, label: '下载', value: download),
          ),
          Container(width: 1, height: 32, color: Colors.white12),
          Expanded(
            child: _SpeedTile(icon: Icons.arrow_upward_rounded, label: '上传', value: upload),
          ),
        ],
      ),
    );
  }
}

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: const Color(0xFFFF6B35)),
              const Gap(4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF6B35),
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
          const Gap(2),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NODE CARD with country flag
// ============================================================

class _MobileNodeCard extends HookConsumerWidget {
  const _MobileNodeCard({required this.nodeName, required this.isDevMode});
  final String nodeName;
  final bool isDevMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected =
        (isDevMode ? ref.watch(mockClientConnectionStateProvider) : ref.watch(clientConnectionStateProvider)).phase ==
        ClientConnectionPhase.connected;
    final countryCode = _extractCountryCode(nodeName);

    return GestureDetector(
      onTap: () => context.goNamed('proxies'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF64748B).withOpacity(.05), blurRadius: 24, offset: const Offset(0, 6)),
            BoxShadow(color: const Color(0xFF64748B).withOpacity(.03), blurRadius: 48, offset: const Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: countryCode != null
                    ? ClipOval(
                        child: Container(
                          color: Colors.white,
                          width: 28,
                          height: 28,
                          child: CircleFlag(countryCode, size: 28),
                        ),
                      )
                    : Icon(Icons.public_rounded, color: const Color(0xFF94A3B8), size: 20),
              ),
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? BrandDesktopColors.success : const Color(0xFFCBD5E1),
                    boxShadow: connected
                        ? [BoxShadow(color: BrandDesktopColors.success.withOpacity(.4), blurRadius: 5)]
                        : null,
                  ),
                ),
                const Gap(5),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ROUTE TOGGLE
// ============================================================

class _RouteToggle extends ConsumerWidget {
  const _RouteToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGlobal = ref.watch(ConfigOptions.globalRouteMode);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleItem(
              selected: !isGlobal,
              label: '智能路由',
              subtitle: '自动分流',
              icon: Icons.route_rounded,
              onTap: () => ref.read(ConfigOptions.globalRouteMode.notifier).update(false),
            ),
          ),
          Expanded(
            child: _ToggleItem(
              selected: isGlobal,
              label: '全局代理',
              subtitle: '全部加速',
              icon: Icons.public_rounded,
              onTap: () => ref.read(ConfigOptions.globalRouteMode.notifier).update(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.selected,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BrandDesktopColors.accent.withOpacity(.12),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          border: selected ? Border.all(color: BrandDesktopColors.accent.withOpacity(.20)) : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: selected ? BrandDesktopColors.accent : const Color(0xFF64748B)),
            const Gap(4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            const Gap(1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: selected ? BrandDesktopColors.accent : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// COUNTRY CODE FROM NODE NAME
// ============================================================

String? _extractCountryCode(String nodeName) {
  final name = nodeName.toLowerCase();
  const map = {
    'us': ['美国', 'usa', 'united states', 'us-', 'us '],
    'jp': ['日本', 'japan', 'jp-', 'jp '],
    'cn': ['中国', 'china', 'cn-', 'cn '],
    'hk': ['香港', 'hong kong', 'hk-', 'hk '],
    'tw': ['台湾', 'taiwan', 'tw-', 'tw '],
    'sg': ['新加坡', 'singapore', 'sg-', 'sg '],
    'kr': ['韩国', 'korea', 'kr-', 'kr '],
    'gb': ['英国', 'uk', 'united kingdom', 'gb-', 'gb '],
    'de': ['德国', 'germany', 'de-', 'de '],
    'fr': ['法国', 'france', 'fr-', 'fr '],
    'ru': ['俄罗斯', 'russia', 'ru-', 'ru '],
    'au': ['澳大利亚', 'australia', 'au-', 'au '],
    'ca': ['加拿大', 'canada', 'ca-', 'ca '],
    'nl': ['荷兰', 'netherlands', 'nl-', 'nl '],
    'in': ['印度', 'india', 'in-', 'in '],
    'br': ['巴西', 'brazil', 'br-', 'br '],
    'it': ['意大利', 'italy', 'it-', 'it '],
    'es': ['西班牙', 'spain', 'es-', 'es '],
    'th': ['泰国', 'thailand', 'th-', 'th '],
    'my': ['马来西亚', 'malaysia', 'my-', 'my '],
    'ph': ['菲律宾', 'philippines', 'ph-', 'ph '],
    'id': ['印尼', 'indonesia', 'id-', 'id '],
    'vn': ['越南', 'vietnam', 'vn-', 'vn '],
    'tr': ['土耳其', 'turkey', 'tr-', 'tr '],
    'ae': ['阿联酋', 'uae', 'ae-', 'ae '],
  };
  for (final entry in map.entries) {
    for (final keyword in entry.value) {
      if (name.contains(keyword)) return entry.key;
    }
  }
  return null;
}
