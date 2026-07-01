import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

class DesktopHomePage extends HookConsumerWidget {
  const DesktopHomePage({super.key});

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
            top: 120,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
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
            bottom: 140,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
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
                Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: const _Header()),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ConnectionHero(state: state, stats: stats, isDevMode: isDevMode),
                ),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _NodeCard(nodeName: nodeName, isDevMode: isDevMode),
                ),
                const Spacer(flex: 2),
                Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: const _RouteToggle()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- outlined text for connected state ----
class _OutlinedText extends StatelessWidget {
  const _OutlinedText({required this.text});
  final String text;

  static final _textStyle = GoogleFonts.notoSansSc(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 5,
    color: const Color(0xFF3B82F6),
  );

  @override
  Widget build(BuildContext context) {
    final span = TextSpan(text: text, style: _textStyle);
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    return SizedBox(
      width: tp.width + 2,
      height: tp.height + 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-1, 0),
            child: Text(text, style: _textStyle.copyWith(color: Colors.white)),
          ),
          Transform.translate(
            offset: const Offset(1, 0),
            child: Text(text, style: _textStyle.copyWith(color: Colors.white)),
          ),
          Transform.translate(
            offset: const Offset(0, -1),
            child: Text(text, style: _textStyle.copyWith(color: Colors.white)),
          ),
          Transform.translate(
            offset: const Offset(0, 1),
            child: Text(text, style: _textStyle.copyWith(color: Colors.white)),
          ),
          Transform.translate(
            offset: const Offset(-1, -1),
            child: Text(text, style: _textStyle.copyWith(color: Colors.white)),
          ),
          Transform.translate(
            offset: const Offset(1, -1),
            child: Text(text, style: _textStyle.copyWith(color: Colors.white)),
          ),
          Transform.translate(
            offset: const Offset(-1, 1),
            child: Text(text, style: _textStyle.copyWith(color: Colors.white)),
          ),
          Transform.translate(
            offset: const Offset(1, 1),
            child: Text(text, style: _textStyle.copyWith(color: Colors.white)),
          ),
          Text(text, style: _textStyle),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/images/app_icon.png', width: 56, height: 56, fit: BoxFit.cover),
        ),
        const Gap(14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(-27, 3),
              child: Image.asset('assets/images/logo_text.png', width: 180, height: 45, fit: BoxFit.contain),
            ),
            const Gap(2),
            Transform.translate(
              offset: const Offset(0, -4),
              child: const Text(
                'Fast, Stable & Secure',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// CONNECTION HERO
// ============================================================

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero({required this.state, required this.stats, required this.isDevMode});
  final ClientConnectionState state;
  final SystemInfo stats;
  final bool isDevMode;

  @override
  Widget build(BuildContext context) {
    final connected = state.phase == ClientConnectionPhase.connected;
    final failed = state.phase == ClientConnectionPhase.failed;

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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: connected
                ? const Color(0xFF4338CA).withOpacity(.30)
                : failed
                ? const Color(0xFFF87171).withOpacity(.10)
                : const Color(0xFF64748B).withOpacity(.12),
            blurRadius: 48,
            spreadRadius: connected ? 2 : 0,
            offset: const Offset(0, 20),
          ),
          if (connected)
            BoxShadow(
              color: BrandDesktopColors.accent.withOpacity(.12),
              blurRadius: 72,
              spreadRadius: 4,
              offset: const Offset(0, 28),
            ),
        ],
      ),
      child: Column(
        children: [
          const Gap(28),

          _StatusChip(state: state),
          const Gap(24),

          _ConnectDial(state: state, isDevMode: isDevMode),
          const Gap(18),

          Text(
            connected
                ? '已连接'
                : state.isBusy
                ? '正在连接...'
                : failed
                ? '连接失败'
                : '未连接',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: connected
                  ? Colors.white
                  : failed
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF64748B),
              letterSpacing: -.2,
            ),
          ),
          const Gap(6),

          Text(
            connected
                ? '您的网络连接已安全加密'
                : state.isBusy
                ? '正在建立安全通道'
                : failed
                ? '请检查网络后重试'
                : state.phase == ClientConnectionPhase.loggedOut
                ? '登录账号后开启加速'
                : '点击上方按钮一键连接',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: connected
                  ? Colors.white54
                  : failed
                  ? const Color(0xFFF87171)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const Gap(24),

          if (connected) _SpeedRow(download: stats.downlink.toInt().speed(), upload: stats.uplink.toInt().speed()),

          const Gap(12),
        ],
      ),
    );
  }
}

// ============================================================
// STATUS CHIP
// ============================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? BrandDesktopColors.accent.withOpacity(.25)
            : failed
            ? const Color(0xFFFFF5F5)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: dark
            ? Border.all(color: BrandDesktopColors.accent.withOpacity(.45))
            : failed
            ? Border.all(color: const Color(0xFFFECACA))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dark) _OutlinedIcon(icon: icon, color: const Color(0xFF3B82F6)) else Icon(icon, size: 15, color: color),
          const Gap(7),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 5,
              color: dark ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- outlined icon for connected state ----
class _OutlinedIcon extends StatelessWidget {
  const _OutlinedIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // white outline via 4-direction offset
          Transform.translate(
            offset: const Offset(-1, 0),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          Transform.translate(
            offset: const Offset(1, 0),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          Transform.translate(
            offset: const Offset(0, -1),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          Transform.translate(
            offset: const Offset(0, 1),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          Transform.translate(
            offset: const Offset(-1, -1),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          Transform.translate(
            offset: const Offset(1, -1),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          Transform.translate(
            offset: const Offset(-1, 1),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          Transform.translate(
            offset: const Offset(1, 1),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          // colored fill on top
          Icon(icon, size: 15, color: color),
        ],
      ),
    );
  }
}

// ============================================================
// CONNECT DIAL
// ============================================================

class _ConnectDial extends ConsumerStatefulWidget {
  const _ConnectDial({required this.state, required this.isDevMode});
  final ClientConnectionState state;
  final bool isDevMode;

  @override
  ConsumerState<_ConnectDial> createState() => _ConnectDialState();
}

class _ConnectDialState extends ConsumerState<_ConnectDial> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulseOuter;
  late Animation<double> _pulseInner;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _pulseOuter = Tween(begin: 0.9, end: 1.12).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, .5, curve: Curves.easeOut),
      ),
    );
    _pulseInner = Tween(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(.2, .7, curve: Curves.easeOut),
      ),
    );
    if (widget.state.isBusy || widget.state.phase == ClientConnectionPhase.connected) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ConnectDial old) {
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
                if (widget.state.phase == ClientConnectionPhase.loggedOut) {
                  ref.read(connectionNotifierProvider.notifier).connectRequested();
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
              width: 144,
              height: 144,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Radial glow (connected)
                  if (connected)
                    Container(
                      width: 160,
                      height: 160,
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
                  if (connected || widget.state.isBusy)
                    Transform.scale(
                      scale: _pulseOuter.value,
                      child: Container(
                        width: 136,
                        height: 136,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent.withOpacity(.15), width: 3),
                        ),
                      ),
                    ),
                  if (connected || widget.state.isBusy)
                    Transform.scale(
                      scale: _pulseInner.value,
                      child: Container(
                        width: 124,
                        height: 124,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent.withOpacity(.25), width: 2.5),
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      boxShadow: [
                        BoxShadow(
                          color: fill.withOpacity(.45),
                          blurRadius: 36,
                          spreadRadius: connected ? 8 : 3,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.state.isBusy
                          ? SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.5,
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
                                width: 108,
                                height: 108,
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

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({required this.download, required this.upload});
  final String download;
  final String upload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Expanded(
            child: _SpeedTile(icon: Icons.arrow_downward_rounded, label: '下载', value: download),
          ),
          Container(width: 1, height: 36, color: Colors.white12),
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
              Icon(icon, size: 14, color: const Color(0xFFFF6B35)),
              const Gap(4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF6B35),
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
          const Gap(3),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
          ),
        ],
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
    'il': ['以色列', 'israel', 'il-', 'il '],
    'za': ['南非', 'south africa', 'za-', 'za '],
    'mx': ['墨西哥', 'mexico', 'mx-', 'mx '],
    'ar': ['阿根廷', 'argentina', 'ar-', 'ar '],
    'ch': ['瑞士', 'switzerland', 'ch-', 'ch '],
    'se': ['瑞典', 'sweden', 'se-', 'se '],
    'no': ['挪威', 'norway', 'no-', 'no '],
    'fi': ['芬兰', 'finland', 'fi-', 'fi '],
    'dk': ['丹麦', 'denmark', 'dk-', 'dk '],
    'pl': ['波兰', 'poland', 'pl-', 'pl '],
    'cz': ['捷克', 'czech', 'cz-', 'cz '],
    'at': ['奥地利', 'austria', 'at-', 'at '],
    'be': ['比利时', 'belgium', 'be-', 'be '],
    'pt': ['葡萄牙', 'portugal', 'pt-', 'pt '],
    'gr': ['希腊', 'greece', 'gr-', 'gr '],
    'ie': ['爱尔兰', 'ireland', 'ie-', 'ie '],
    'nz': ['新西兰', 'new zealand', 'nz-', 'nz '],
    'eg': ['埃及', 'egypt', 'eg-', 'eg '],
    'sa': ['沙特', 'saudi', 'sa-', 'sa '],
    'qa': ['卡塔尔', 'qatar', 'qa-', 'qa '],
    'kw': ['科威特', 'kuwait', 'kw-', 'kw '],
    'bh': ['巴林', 'bahrain', 'bh-', 'bh '],
    'om': ['阿曼', 'oman', 'om-', 'om '],
    'pk': ['巴基斯坦', 'pakistan', 'pk-', 'pk '],
    'bd': ['孟加拉', 'bangladesh', 'bd-', 'bd '],
    'lk': ['斯里兰卡', 'sri lanka', 'lk-', 'lk '],
    'np': ['尼泊尔', 'nepal', 'np-', 'np '],
    'mm': ['缅甸', 'myanmar', 'mm-', 'mm '],
    'kh': ['柬埔寨', 'cambodia', 'kh-', 'kh '],
    'la': ['老挝', 'laos', 'la-', 'la '],
    'mn': ['蒙古', 'mongolia', 'mn-', 'mn '],
    'kz': ['哈萨克斯坦', 'kazakhstan', 'kz-', 'kz '],
    'uz': ['乌兹别克', 'uzbekistan', 'uz-', 'uz '],
    'ua': ['乌克兰', 'ukraine', 'ua-', 'ua '],
    'by': ['白俄罗斯', 'belarus', 'by-', 'by '],
    'ro': ['罗马尼亚', 'romania', 'ro-', 'ro '],
    'bg': ['保加利亚', 'bulgaria', 'bg-', 'bg '],
    'hu': ['匈牙利', 'hungary', 'hu-', 'hu '],
    'rs': ['塞尔维亚', 'serbia', 'rs-', 'rs '],
    'hr': ['克罗地亚', 'croatia', 'hr-', 'hr '],
    'sk': ['斯洛伐克', 'slovakia', 'sk-', 'sk '],
    'si': ['斯洛文尼亚', 'slovenia', 'si-', 'si '],
    'lt': ['立陶宛', 'lithuania', 'lt-', 'lt '],
    'lv': ['拉脱维亚', 'latvia', 'lv-', 'lv '],
    'ee': ['爱沙尼亚', 'estonia', 'ee-', 'ee '],
    'is': ['冰岛', 'iceland', 'is-', 'is '],
    'lu': ['卢森堡', 'luxembourg', 'lu-', 'lu '],
    'mt': ['马耳他', 'malta', 'mt-', 'mt '],
    'cy': ['塞浦路斯', 'cyprus', 'cy-', 'cy '],
    'cl': ['智利', 'chile', 'cl-', 'cl '],
    'pe': ['秘鲁', 'peru', 'pe-', 'pe '],
    'co': ['哥伦比亚', 'colombia', 'co-', 'co '],
    've': ['委内瑞拉', 'venezuela', 've-', 've '],
    'ec': ['厄瓜多尔', 'ecuador', 'ec-', 'ec '],
    'uy': ['乌拉圭', 'uruguay', 'uy-', 'uy '],
    'py': ['巴拉圭', 'paraguay', 'py-', 'py '],
    'bo': ['玻利维亚', 'bolivia', 'bo-', 'bo '],
    'ng': ['尼日利亚', 'nigeria', 'ng-', 'ng '],
    'ke': ['肯尼亚', 'kenya', 'ke-', 'ke '],
    'gh': ['加纳', 'ghana', 'gh-', 'gh '],
    'tz': ['坦桑尼亚', 'tanzania', 'tz-', 'tz '],
    'ug': ['乌干达', 'uganda', 'ug-', 'ug '],
    'et': ['埃塞俄比亚', 'ethiopia', 'et-', 'et '],
    'ma': ['摩洛哥', 'morocco', 'ma-', 'ma '],
    'tn': ['突尼斯', 'tunisia', 'tn-', 'tn '],
    'dz': ['阿尔及利亚', 'algeria', 'dz-', 'dz '],
    'ly': ['利比亚', 'libya', 'ly-', 'ly '],
    'sd': ['苏丹', 'sudan', 'sd-', 'sd '],
    'jo': ['约旦', 'jordan', 'jo-', 'jo '],
    'lb': ['黎巴嫩', 'lebanon', 'lb-', 'lb '],
    'sy': ['叙利亚', 'syria', 'sy-', 'sy '],
    'iq': ['伊拉克', 'iraq', 'iq-', 'iq '],
    'ir': ['伊朗', 'iran', 'ir-', 'ir '],
    'af': ['阿富汗', 'afghanistan', 'af-', 'af '],
  };
  for (final entry in map.entries) {
    for (final keyword in entry.value) {
      if (name.contains(keyword)) return entry.key;
    }
  }
  return null;
}

// ============================================================
// NODE CARD
// ============================================================

class _NodeCard extends HookConsumerWidget {
  const _NodeCard({required this.nodeName, required this.isDevMode});
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
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF64748B).withOpacity(.05), blurRadius: 32, offset: const Offset(0, 8)),
            BoxShadow(color: const Color(0xFF64748B).withOpacity(.03), blurRadius: 64, offset: const Offset(0, 16)),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: countryCode != null
                    ? ClipOval(
                        child: Container(
                          color: Colors.white,
                          width: 32,
                          height: 32,
                          child: CircleFlag(countryCode, size: 32),
                        ),
                      )
                    : Icon(Icons.public_rounded, color: const Color(0xFF94A3B8), size: 22),
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前节点',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                  ),
                  const Gap(3),
                  Text(
                    nodeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? BrandDesktopColors.success : const Color(0xFFCBD5E1),
                    boxShadow: connected
                        ? [BoxShadow(color: BrandDesktopColors.success.withOpacity(.4), blurRadius: 6)]
                        : null,
                  ),
                ),
                const Gap(6),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 22),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BrandDesktopColors.accent.withOpacity(.12),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
          border: selected ? Border.all(color: BrandDesktopColors.accent.withOpacity(.20)) : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? BrandDesktopColors.accent : const Color(0xFF64748B)),
            const Gap(5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            const Gap(1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
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
