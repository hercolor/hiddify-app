import 'dart:async';

import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/dev_mode/dev_mode_providers.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/proxy/overview/desktop_nodes_page.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/widget/safe_node_display_name.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _nodeSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class ProxiesOverviewPage extends HookConsumerWidget {
  const ProxiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isWindows) return const DesktopNodesPage();

    final isDevMode = ref.watch(devModeProvider);
    final search = ref.watch(_nodeSearchProvider).trim().toLowerCase();

    // Debug 模式下使用模拟节点
    if (isDevMode) {
      final mockSelection = ref.watch(mockClientNodeSelectionProvider);
      _useAutoLatencyRefresh(ref, null);
      return _buildMockNodesPage(context, ref, mockSelection.nodes, search);
    }

    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    _useAutoLatencyRefresh(ref, proxies.valueOrNull?.tag);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.goNamed('home');
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                    ),
                  ),
                  const Text('选择节点', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            // Search bar + speed test
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) => ref.read(_nodeSearchProvider.notifier).state = value,
                        decoration: const InputDecoration(
                          hintText: '搜索国家或地区...',
                          prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const Gap(10),
                  _TestSpeedButton(groupTag: proxies.valueOrNull?.tag),
                ],
              ),
            ),
            const Gap(12),
            // Node list
            Expanded(
              child: proxies.when(
                data: (group) => group == null
                    ? _CachedNodesList(search: search)
                    : RefreshIndicator(
                        onRefresh: () => ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(group.tag),
                        child: _CachedNodesList(search: search),
                      ),
                error: (_, _) => _CachedNodesList(search: search),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockNodesPage(BuildContext context, WidgetRef ref, List<ClientNode> nodes, String search) {
    final filteredNodes = search.isEmpty
        ? nodes
        : nodes.where((node) => safeNodeDisplayName(node.name).toLowerCase().contains(search)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.goNamed('home');
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                    ),
                  ),
                  const Text('选择节点', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: TextField(
                  onChanged: (value) => ref.read(_nodeSearchProvider.notifier).state = value,
                  decoration: const InputDecoration(
                    hintText: '搜索国家或地区...',
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const Gap(12),
            // Mock node list
            Expanded(
              child: filteredNodes.isEmpty
                  ? const _EmptyNodes()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: filteredNodes.length,
                      separatorBuilder: (_, __) => const Gap(12),
                      itemBuilder: (context, index) {
                        final node = filteredNodes[index];
                        return _NodeTile(
                          node: node,
                          selected: index == 0,
                          onTap: () {
                            ref.read(mockClientNodeSelectionProvider.notifier).selectNode(node.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TEST SPEED BUTTON (round icon style like desktop)
// ============================================================

class _TestSpeedButton extends ConsumerWidget {
  const _TestSpeedButton({required this.groupTag});

  final String? groupTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canTest = groupTag != null && groupTag!.isNotEmpty;
    return GestureDetector(
      onTap: canTest
          ? () async {
              try {
                ref.read(inAppNotificationControllerProvider).showInfoToast('正在测试所有节点延迟');
                await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(groupTag!);
              } catch (_) {
                ref.read(inAppNotificationControllerProvider).showErrorToast('测速失败');
              }
            }
          : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: canTest ? BrandDesktopColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: canTest
              ? [
                  BoxShadow(
                    color: BrandDesktopColors.accent.withOpacity(.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
        ),
        child: Icon(Icons.speed_rounded, color: canTest ? Colors.white : const Color(0xFF94A3B8), size: 20),
      ),
    );
  }
}

void _useAutoLatencyRefresh(WidgetRef ref, String? groupTag) {
  useEffect(() {
    if (groupTag == null || groupTag.isEmpty) return null;

    var disposed = false;
    Future<void> refresh() async {
      if (disposed) return;
      try {
        await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(groupTag, withHaptic: false);
      } catch (_) {
        // Keep the node page responsive; manual pull-to-refresh still surfaces failures.
      }
    }

    unawaited(Future<void>.microtask(refresh));
    final timer = Timer.periodic(const Duration(seconds: 10), (_) => unawaited(refresh()));
    return () {
      disposed = true;
      timer.cancel();
    };
  }, [groupTag]);
}

// ============================================================
// NODE LIST
// ============================================================

class _CachedNodesList extends ConsumerWidget {
  const _CachedNodesList({required this.search});

  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(clientNodeSelectionProvider);
    return selection.when(
      data: (state) {
        final items = search.isEmpty
            ? state.nodes
            : state.nodes
                  .where((node) => safeNodeDisplayName(node.name).toLowerCase().contains(search))
                  .toList(growable: false);
        if (items.isEmpty) return const _EmptyNodes();
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Gap(12),
          itemBuilder: (context, index) {
            final node = items[index];
            return _NodeTile(
              node: node,
              selected: state.effectiveSelectedNodeId == node.id,
              onTap: () => _selectCachedNode(ref, node.id, state.effectiveSelectedNodeId == node.id),
            );
          },
        );
      },
      error: (_, _) => const _EmptyNodes(),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

// ============================================================
// NODE TILE (desktop style with flag and glow)
// ============================================================

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node, required this.selected, required this.onTap});

  final ClientNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final delay = node.delay;
    final delayText = delay == null || delay == 0
        ? '待测速'
        : delay > 65000
        ? '超时'
        : '$delay ms';
    final delayColor = _delayColor(delay);
    final name = safeNodeDisplayName(node.name);
    final countryCode = _extractCountryCode(name);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.0 : 0.985,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? BrandDesktopColors.accent.withOpacity(.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? BrandDesktopColors.accent.withOpacity(.30) : const Color(0xFFF1F5F9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? BrandDesktopColors.accent.withOpacity(.12)
                    : const Color(0xFF0F172A).withOpacity(.03),
                blurRadius: selected ? 16 : 10,
                offset: Offset(0, selected ? 5.0 : 3.0),
              ),
              if (selected)
                BoxShadow(
                  color: BrandDesktopColors.accent.withOpacity(.06),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            children: [
              // Country flag
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? BrandDesktopColors.accent.withOpacity(0.1) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? BrandDesktopColors.accent.withOpacity(0.3) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: countryCode != null
                      ? CircleFlag(countryCode, size: 22)
                      : Icon(
                          Icons.public_rounded,
                          color: selected ? BrandDesktopColors.accent : const Color(0xFF94A3B8),
                          size: 18,
                        ),
                ),
              ),
              const Gap(12),
              // Node name
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? BrandDesktopColors.accent : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const Gap(8),
              // Delay badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: delayColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  delayText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: delayColor,
                  ),
                ),
              ),
              const Gap(8),
              // Selection indicator
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? BrandDesktopColors.accent : const Color(0xFFCBD5E1),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

Color _delayColor(int? delay) {
  if (delay == null || delay == 0) return const Color(0xFF94A3B8);
  if (delay < 800) return const Color(0xFF34C759);
  if (delay < 1500) return const Color(0xFFFF9500);
  return const Color(0xFFFF3B30);
}

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

Future<void> _selectCachedNode(WidgetRef ref, String nodeId, bool selected) async {
  if (selected) return;
  final state = ref.read(clientConnectionStateProvider);
  final wasConnected = state.phase == ClientConnectionPhase.connected;

  if (wasConnected) {
    ref.read(inAppNotificationControllerProvider).showInfoToast('正在切换节点并重新连接');
  }
  try {
    await ref.read(connectionNotifierProvider.notifier).switchSelectedNode(nodeId);
  } catch (_) {
    ref.read(inAppNotificationControllerProvider).showErrorToast('切换节点失败，请稍后重试');
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyNodes extends StatelessWidget {
  const _EmptyNodes();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withOpacity(.03), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: BrandDesktopColors.accent.withOpacity(.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.hub_rounded, color: Color(0xFF0EA5E9), size: 32),
            ),
            const Gap(18),
            const Text(
              '暂无可用节点',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            const Gap(8),
            const Text('请稍后重试或联系客服', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
